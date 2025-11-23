//
//  DataSyncManager.swift
//  VTNECards
//
//  Created by David Cardona on 11/22/25.
//

import Foundation
import Combine

struct ManifestFile: Codable, Hashable {
    let path: String          // e.g. "Animal Care and Nursing Flashcards.json"
    let type: String          // "json" or "image"
    let sourceDocx: String    // "Animal Care and Nursing Flashcards.docx"
    let parsedAt: Date        // parsed_at timestamp

    enum CodingKeys: String, CodingKey {
        case path
        case type
        case sourceDocx = "source_docx"
        case parsedAt = "parsed_at"
    }
}

struct Manifest: Codable {
    let generatedAt: Date
    let files: [ManifestFile]

    enum CodingKeys: String, CodingKey {
        case generatedAt = "generated_at"
        case files
    }

    var jsonFiles: [ManifestFile] {
        files.filter { $0.type == "json" }
    }

    var imageFiles: [ManifestFile] {
        files.filter { $0.type == "image" }
    }
}

@MainActor
final class DataSyncManager: ObservableObject {
    static let shared = DataSyncManager()

    @Published var isSyncing = false
    @Published var lastSyncError: Error?
    @Published var currentManifest: Manifest?

    /// Change this to match your repo path
    /// e.g. https://raw.githubusercontent.com/<USER>/<REPO>/main/data
    private let baseRemoteURL = URL(string: "https://raw.githubusercontent.com/dcardonab/VTNECards/main/data")!

    private init() {}

    // Call this once on app launch
    func syncIfNeeded() async {
        do {
            try AppPaths.ensureFoldersExist()

            let remoteManifest = try await fetchRemoteManifest()
            let localManifest = loadLocalManifest()

            if let local = localManifest, local.generatedAt >= remoteManifest.generatedAt {
                currentManifest = local
                return
            }

            let filesToDownload = filesToDownload(remote: remoteManifest,
                                                  local: localManifest)

            guard !filesToDownload.isEmpty else {
                try saveLocalManifest(remoteManifest)
                // No file-level changes but manifest is newer
                try cleanupLocalFiles(using: remoteManifest)
                currentManifest = remoteManifest
                return
            }

            isSyncing = true
            try await download(files: filesToDownload)
            try saveLocalManifest(remoteManifest)
            try cleanupLocalFiles(using: remoteManifest)

            currentManifest = remoteManifest
            lastSyncError = nil
        } catch {
            lastSyncError = error
            print("Sync error: \(error)")
        }
        isSyncing = false
    }
}

// MARK: - Manifest helpers

extension DataSyncManager {
    private func fetchRemoteManifest() async throws -> Manifest {
        let url = baseRemoteURL
            .appendingPathComponent("json")
            .appendingPathComponent("manifest.json")

        let (data, _) = try await URLSession.shared.data(from: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(Manifest.self, from: data)
    }

    private func loadLocalManifest() -> Manifest? {
        let url = AppPaths.localManifestURL
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }

        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(Manifest.self, from: data)
        } catch {
            print("Failed to load local manifest: \(error)")
            return nil
        }
    }

    private func saveLocalManifest(_ manifest: Manifest) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(manifest)
        try data.write(to: AppPaths.localManifestURL, options: .atomic)
    }

    /// Return only files whose parsedAt is newer than local (or missing locally).
    private func filesToDownload(remote: Manifest,
                                 local: Manifest?) -> [ManifestFile] {
        guard let local = local else { return remote.files }

        let localDict = Dictionary(uniqueKeysWithValues:
            local.files.map { ($0.path, $0.parsedAt) }
        )

        return remote.files.filter { file in
            guard let localParsed = localDict[file.path] else {
                // New file
                return true
            }
            return file.parsedAt > localParsed
        }
    }
}

// MARK: - Download files

extension DataSyncManager {
    private func download(files: [ManifestFile]) async throws {
        for file in files {
            let subfolder = (file.type == "json") ? "json" : "images"
            let localFolder = (file.type == "json") ? AppPaths.jsonFolder : AppPaths.imagesFolder

            try await downloadFile(
                remoteSubfolder: subfolder,
                localFolder: localFolder,
                filename: file.path
            )
        }
    }

    private func downloadFile(remoteSubfolder: String,
                              localFolder: URL,
                              filename: String) async throws {
        let remoteURL = baseRemoteURL
            .appendingPathComponent(remoteSubfolder)
            .appendingPathComponent(filename)

        let (data, response) = try await URLSession.shared.data(from: remoteURL)

        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            throw NSError(domain: "DataSync",
                          code: http.statusCode,
                          userInfo: [NSLocalizedDescriptionKey:
                                     "Failed to download \(filename): HTTP \(http.statusCode)"])
        }

        let localURL = localFolder.appendingPathComponent(filename)
        try data.write(to: localURL, options: .atomic)
    }
}


extension DataSyncManager {
    /// Remove any JSON/image files in the sandbox that are not present in the manifest.
    private func cleanupLocalFiles(using manifest: Manifest) throws {
        let fm = FileManager.default

        // Allowed filenames from manifest
        let allowedJSONNames = Set(manifest.jsonFiles.map { $0.path })   // full filenames, e.g. "Parasitology Flashcards.json"
        let allowedImageNames = Set(manifest.imageFiles.map { $0.path }) // e.g. "Parasitology Flashcards_Image01.png"

        // --- JSON folder ---
        if fm.fileExists(atPath: AppPaths.jsonFolder.path) {
            let contents = try fm.contentsOfDirectory(atPath: AppPaths.jsonFolder.path)
            for name in contents {
                // Keep manifest.json itself
                if name == "manifest.json" { continue }

                // If not in manifest, remove it
                if !allowedJSONNames.contains(name) {
                    let url = AppPaths.jsonFolder.appendingPathComponent(name)
                    do {
                        try fm.removeItem(at: url)
                        print("🧹 Removed stale JSON file: \(name)")
                    } catch {
                        print("⚠️ Failed to remove JSON \(name): \(error)")
                    }
                }
            }
        }

        // --- Images folder ---
        if fm.fileExists(atPath: AppPaths.imagesFolder.path) {
            let contents = try fm.contentsOfDirectory(atPath: AppPaths.imagesFolder.path)
            for name in contents {
                if !allowedImageNames.contains(name) {
                    let url = AppPaths.imagesFolder.appendingPathComponent(name)
                    do {
                        try fm.removeItem(at: url)
                        print("🧹 Removed stale image file: \(name)")
                    } catch {
                        print("⚠️ Failed to remove image \(name): \(error)")
                    }
                }
            }
        }
    }
}


enum AppPaths {
    static var appSupport: URL {
        let url = FileManager.default.urls(for: .applicationSupportDirectory,
                                           in: .userDomainMask)[0]
        // Optionally, you can append bundle identifier here:
        // return url.appendingPathComponent(Bundle.main.bundleIdentifier ?? "VTNECards", isDirectory: true)
        return url
    }

    static var dataRoot: URL {
        appSupport.appendingPathComponent("data", isDirectory: true)
    }

    static var jsonFolder: URL {
        dataRoot.appendingPathComponent("json", isDirectory: true)
    }

    static var imagesFolder: URL {
        dataRoot.appendingPathComponent("images", isDirectory: true)
    }

    static var localManifestURL: URL {
        jsonFolder.appendingPathComponent("manifest.json")
    }

    static func ensureFoldersExist() throws {
        let fm = FileManager.default
        try fm.createDirectory(at: jsonFolder, withIntermediateDirectories: true)
        try fm.createDirectory(at: imagesFolder, withIntermediateDirectories: true)
    }
}

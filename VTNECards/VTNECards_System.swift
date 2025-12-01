//
//  VTNECards_System.swift
//  VTNECards
//
//  Created by David Cardona on 11/16/25.
//

import SwiftUI
import Foundation

struct Flashcard: Codable {
    let title: String
    let content: String

    enum CodingKeys: String, CodingKey {
        case title
        case content = "detail"
    }
}


struct FlashcardCategory: Codable {
    let name: String
    let cards: [Flashcard]
}


func loadFlashcards(from filename: String) -> [Flashcard]? {
    let fm = FileManager.default

    // 1. Prefer sandbox JSON
    let localURL = AppPaths.jsonFolder.appendingPathComponent("\(filename).json")
    if fm.fileExists(atPath: localURL.path) {
        do {
            let data = try Data(contentsOf: localURL)
            let flashcards = try JSONDecoder().decode([Flashcard].self, from: data)
            return flashcards
        } catch {
            print("Error decoding local \(filename).json: \(error)")
        }
    }

    // 2. Fall back to bundled JSON
    guard let url = Bundle.main.url(forResource: filename, withExtension: "json") else {
        print("Couldn't find \(filename).json in bundle: \(Bundle.main.bundlePath)")
        return nil
    }

    do {
        let data = try Data(contentsOf: url)
        let flashcards = try JSONDecoder().decode([Flashcard].self, from: data)
        return flashcards
    } catch {
        print("Error decoding bundled \(filename).json: \(error)")
        return nil
    }
}


/// Loads flashcards for production and previews, falling back to sample data if the JSON is missing.
func loadFlashcardsSafe(from filename: String) -> [Flashcard] {
    if let cards = loadFlashcards(from: filename), !cards.isEmpty {
        return cards
    }
    print("Using sample flashcards because \(filename).json was not found or empty.")
    return [
        Flashcard(title: "Sample", content: "This is a sample card used when JSON isn't available in previews."),
        Flashcard(title: "How to add JSON", content: "Add your .json to the project, ensure Target Membership is checked, and it appears in Copy Bundle Resources.")
    ]
}


/// Returns all JSON file names in the main bundle (without .json extension) to use as categories.
func categoryJSONFileNames() -> [String] {
    var names = Set<String>()
    let fm = FileManager.default

    // 1. Bundle JSONs
    if let resourcePath = Bundle.main.resourcePath {
        let allFiles = (try? fm.contentsOfDirectory(atPath: resourcePath)) ?? []
        for filename in allFiles where filename.hasSuffix(".json") {
            let base = (filename as NSString).deletingPathExtension
            guard base.lowercased() != "manifest" else { continue }
            names.insert(base)
        }
    }

    // 2. Sandbox JSONs
    let localJSONPath = AppPaths.jsonFolder.path
    if fm.fileExists(atPath: localJSONPath) {
        let localFiles = (try? fm.contentsOfDirectory(atPath: localJSONPath)) ?? []
        for filename in localFiles where filename.hasSuffix(".json") {
            let base = (filename as NSString).deletingPathExtension
            guard base.lowercased() != "manifest" else { continue }
            names.insert(base)
        }
    }

    return names.sorted()
}


/// Returns all JSON file names in the *bundle* (without .json extension),
/// used only as a fallback when no manifest is available.
func bundleCategoryJSONFileNames() -> [String] {
    guard let resourcePath = Bundle.main.resourcePath else {
        print("Bundle.main.resourcePath is nil for bundle: \(Bundle.main.bundlePath)")
        return []
    }

    let fileManager = FileManager.default
    let allFiles = (try? fileManager.contentsOfDirectory(atPath: resourcePath)) ?? []

    return allFiles.compactMap { filename in
        guard filename.hasSuffix(".json") else { return nil }

        let base = (filename as NSString).deletingPathExtension

        // Never treat manifest.json as a category
        guard base.lowercased() != "manifest" else { return nil }

        return base
    }
}




/// Creates an imageProvider that loads images from the same folder as the JSON file for this category.
/// Assumes `categoryFile` is the JSON base name without extension, e.g., "AnimalCare" -> "AnimalCare.json".
func makeImageProvider(forCategoryFile categoryFile: String) -> (String) -> Image? {
    // Where remote images live:
    let sandboxImagesFolder = AppPaths.imagesFolder

    // Where bundled JSON (and possibly bundled images) live:
    let bundleJSONURL = Bundle.main.url(forResource: categoryFile, withExtension: "json")
    let bundleDirectory = bundleJSONURL?.deletingLastPathComponent()

    return { filename in
        let fm = FileManager.default

        // 1. Sandbox image
        let sandboxURL = sandboxImagesFolder.appendingPathComponent(filename)
        #if canImport(UIKit)
        if fm.fileExists(atPath: sandboxURL.path),
           let uiImage = UIImage(contentsOfFile: sandboxURL.path) {
            return Image(uiImage: uiImage)
        }
        #elseif canImport(AppKit)
        if fm.fileExists(atPath: sandboxURL.path),
           let nsImage = NSImage(contentsOf: sandboxURL) {
            return Image(nsImage: nsImage)
        }
        #endif

        // 2. Fallback: bundle "next to JSON" (your original behavior)
        if let directory = bundleDirectory {
            let fileURL = directory.appendingPathComponent(filename)
            #if canImport(UIKit)
            if let uiImage = UIImage(contentsOfFile: fileURL.path) {
                return Image(uiImage: uiImage)
            }
            #elseif canImport(AppKit)
            if let nsImage = NSImage(contentsOf: fileURL) {
                return Image(nsImage: nsImage)
            }
            #endif
        }

        print("⚠️ Could not load image \(filename) from sandbox or bundle")
        return nil
    }
}


/// Creates a UIImage provider that loads images from the same folder as the JSON file for this category.
/// Useful for zoomable views that need UIKit images.
func makeUIImageProvider(forCategoryFile categoryFile: String) -> (String) -> UIImage? {
    let sandboxImagesFolder = AppPaths.imagesFolder
    let bundleJSONURL = Bundle.main.url(forResource: categoryFile, withExtension: "json")
    let bundleDirectory = bundleJSONURL?.deletingLastPathComponent()

    return { filename in
        let fm = FileManager.default

        // 1. Sandbox
        let sandboxURL = sandboxImagesFolder.appendingPathComponent(filename)
        #if canImport(UIKit)
        if fm.fileExists(atPath: sandboxURL.path),
           let uiImage = UIImage(contentsOfFile: sandboxURL.path) {
            return uiImage
        }
        #endif

        // 2. Bundle fallback
        if let directory = bundleDirectory {
            let fileURL = directory.appendingPathComponent(filename)
            #if canImport(UIKit)
            if fm.fileExists(atPath: fileURL.path) {
                return UIImage(contentsOfFile: fileURL.path)
            }
            #endif
        }

        return nil
    }
}


/// Formats a file name into a user-friendly category display name.
func categoryDisplayName(forFile fileName: String) -> String {
    return fileName
        .replacingOccurrences(of: "_", with: " ")
        .capitalized
}


/// Parses `[[image:filename.png]]` tokens out of the text.
/// Returns the plain text (with tokens removed) and a list of filenames.
func parseTextAndImageTokens(_ text: String) -> (plainText: String, images: [String]) {
    var remaining = text[...]
    var plainParts: [Substring] = []
    var images: [String] = []

    let startToken = "[[image:"
    let endToken = "]]"

    while let startRange = remaining.range(of: startToken) {
        // Text before the token
        let before = remaining[..<startRange.lowerBound]
        plainParts.append(before)

        let imageNameStart = startRange.upperBound
        guard let endRange = remaining.range(of: endToken, range: imageNameStart..<remaining.endIndex) else {
            // No closing token – treat the rest as plain text
            plainParts.append(remaining[startRange.lowerBound...])
            remaining = remaining[remaining.endIndex...]
            break
        }

        let nameRange = imageNameStart..<endRange.lowerBound
        let filename = String(remaining[nameRange]).trimmingCharacters(in: .whitespacesAndNewlines)
        if !filename.isEmpty {
            images.append(filename)
        }

        // Continue after the closing token
        remaining = remaining[endRange.upperBound...]
    }

    // Whatever is left is plain text
    if !remaining.isEmpty {
        plainParts.append(remaining)
    }

    let plainText = plainParts.joined()
    return (String(plainText), images)
}


#if DEBUG
/// Convenience accessor for previews: update the filename to match your resource name without ".json".
var previewFlashcards: [Flashcard] {
    loadFlashcardsSafe(from: "ParasitologyFlashcards")
}
#endif

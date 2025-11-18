//
//  FlashcardSystem.swift
//  Flashcards
//
//  Created by David Cardona on 11/16/25.
//

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
    guard let url = Bundle.main.url(forResource: filename, withExtension: "json") else {
        print("Couldn't find \(filename).json in bundle: \(Bundle.main.bundlePath)")
        return nil
    }

    do {
        let data = try Data(contentsOf: url)
        let flashcards = try JSONDecoder().decode([Flashcard].self, from: data)
        return flashcards
    } catch {
        print("Error decoding \(filename).json: \(error)")
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
    guard let resourcePath = Bundle.main.resourcePath else {
        print("Bundle.main.resourcePath is nil for bundle: \(Bundle.main.bundlePath)")
        return []
    }

    let fileManager = FileManager.default
    let allFiles = (try? fileManager.contentsOfDirectory(atPath: resourcePath)) ?? []

    return allFiles.compactMap { filename in
        guard filename.hasSuffix(".json") else { return nil }
        return (filename as NSString).deletingPathExtension
    }
}

/// Formats a file name into a user-friendly category display name.
func categoryDisplayName(forFile fileName: String) -> String {
    return fileName
        .replacingOccurrences(of: "_", with: " ")
        .capitalized
}

#if DEBUG
/// Convenience accessor for previews: update the filename to match your resource name without ".json".
var previewFlashcards: [Flashcard] {
    loadFlashcardsSafe(from: "ParasitologyFlashcards")
}
#endif

//
//  ContentView.swift
//  Flashcards
//
//  Created by David Cardona on 11/16/25.
//

import SwiftUI

struct LandingView: View {
    var body: some View {
        ZStack {
            NavigationStack {
                CategoriesView()
                    .navigationTitle("Categories")
            }
        }
        .foregroundStyle(Color.black)
    }
}

struct CategoriesView: View {
    let categoryFiles = categoryJSONFileNames()
    
    var body: some View {
        ZStack {
            List(categoryFiles, id: \.self) { fileName in
                NavigationLink("\(categoryDisplayName(forFile: fileName)) \(AnimalEmoji.random())") {
                    CategoryDetailView(categoryFile: fileName)
                }
                .miffyListRow()
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(MiffyTheme.pastelBackground.ignoresSafeArea())
        }
    }
}

struct CategoryDetailView: View {
    let categoryFile: String
    private var flashcards: [Flashcard] {
        loadFlashcardsSafe(from: categoryFile)
    }

    var body: some View {
        ZStack {
            List {
                NavigationLink("All \(categoryFile) Flashcards \(AnimalEmoji.random())") {
                    CategoryFlashcardsView(categoryFile: categoryFile)
                }
                .miffyListRow()
                NavigationLink("Random Drill \(AnimalEmoji.random())") {
                    RandomDrillView(cards: flashcards, categoryTitle: categoryDisplayName(forFile: categoryFile))
                }
                .miffyListRow()
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(MiffyTheme.pastelBackground.ignoresSafeArea())
        }
        .navigationTitle("\(categoryFile)")
    }
}

struct CategoryFlashcardsView: View {
    let categoryFile: String
    private var flashcards: [Flashcard] {
        loadFlashcardsSafe(from: categoryFile)
    }
    
    var body: some View {
        ZStack {
            List(flashcards, id: \.title) { flashcard in
                NavigationLink(flashcard.title) {
                    FlashcardView(flashcard: flashcard)
                }
                .miffyListRow()
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(MiffyTheme.pastelBackground.ignoresSafeArea())
        }
        .navigationTitle(categoryFile)
    }
}

struct RandomDrillView: View {
    let cards: [Flashcard]
    let categoryTitle: String

    @State private var currentIndex: Int = 0
    @State private var showingDetail: Bool = false

    var body: some View {
        ZStack(alignment: .top) {
            MiffyTheme.pastelBackground.ignoresSafeArea()

            VStack(alignment: .leading) {

                // Card switcher
                ZStack {
                    cardView(for: cards[currentIndex])
                        .id(currentIndex) // <- identity changes when index changes
                        .transition(
                            .asymmetric(
                                insertion: .move(edge: .trailing),
                                removal: .move(edge: .leading)
                            )
                        )
                }

                Spacer()
            }
            .onTapGesture { advance() }
            .padding()
            .onAppear { startIfNeeded() }
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack {
                    ThemedTitle(text: "\(categoryTitle)")
                    Text("Random Drill")
                        .font(.subheadline)
                }
            }
        }
    }

    // MARK: - Subview

    @ViewBuilder
    private func cardView(for card: Flashcard) -> some View {
        VStack(alignment: .leading) {
            ThemedTitle(text: card.title)
                .frame(maxWidth: .infinity, alignment: .leading)

            if showingDetail {
                BulletListView(text: card.content)
            } else {
                Text("Tap to reveal detail")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 6)
            }
        }
        .miffyCard()
    }

    // MARK: - Logic

    private func startIfNeeded() {
        guard !cards.isEmpty else { return }
        currentIndex = Int.random(in: 0..<cards.count)
        showingDetail = false
    }

    private func advance() {
        guard !cards.isEmpty else { return }

        if showingDetail {
            // Go to next card WITH slide animation
            var next = Int.random(in: 0..<cards.count)
            if cards.count > 1 {
                while next == currentIndex { next = Int.random(in: 0..<cards.count) }
            }

            withAnimation(.easeInOut) {
                showingDetail = false   // new card should start on front side
                currentIndex = next     // triggers the slide transition
            }

        } else {
            // Reveal detail on the same card (no slide, just content animation)
            withAnimation(.easeInOut) {
                showingDetail = true
            }
        }
    }
}


struct FlashcardView: View {
    let flashcard: Flashcard
    var body: some View {
        ZStack {
            VStack {
                VStack(alignment: .leading) {
                    ThemedTitle(text: flashcard.title)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Spacer(minLength: 20)
                    BulletListView(text: flashcard.content)
                }
                .miffyCard()
            }
            .padding()
        }
        .background(MiffyTheme.pastelBackground.ignoresSafeArea())
        .toolbar {
            ToolbarItem(placement: .principal) {
                ThemedTitle(text: "\(flashcard.title)")
            }
        }
    }
}

struct BulletListView: View {
    let text: String

    private struct Line: Identifiable {
        let id = UUID()
        let level: Int
        let bullet: String?
        let content: String
    }

    private let spacesPerIndentLevel = 4
    private let indentUnit: CGFloat = 16
    private let bulletColumnWidth: CGFloat = 14

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(parseLines(from: text)) { line in
                    HStack(alignment: .top, spacing: 8) {
                        // Fixed bullet column to avoid wrap overlap
                        if let bullet = line.bullet {
                            Text(bullet)
                                .foregroundStyle(MiffyTheme.charcoal)
                                .frame(width: bulletColumnWidth, alignment: .trailing)
                        } else {
                            Color.clear
                                .frame(width: bulletColumnWidth)
                        }

                        Text(line.content)
                            .foregroundStyle(MiffyTheme.charcoal)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.leading, CGFloat(line.level) * indentUnit)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 2)
        }
    }

    private func parseLines(from raw: String) -> [Line] {
        var result: [Line] = []
        for rawLine in raw.components(separatedBy: .newlines) {
            let trimmedRight = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            // Skip empty lines but preserve paragraph breaks as blank entries
            if trimmedRight.isEmpty {
                result.append(Line(level: 0, bullet: nil, content: ""))
                continue
            }

            // Count leading spaces/tabs
            var level = 0
            var index = rawLine.startIndex
            var spaceCount = 0
            while index < rawLine.endIndex {
                let ch = rawLine[index]
                if ch == "\t" {
                    // treat a tab as one level
                    level += 1
                    index = rawLine.index(after: index)
                } else if ch == " " {
                    spaceCount += 1
                    index = rawLine.index(after: index)
                } else {
                    break
                }
            }
            if spacesPerIndentLevel > 0 {
                level += spaceCount / spacesPerIndentLevel
            }

            // Detect bullet symbol
            var bullet: String? = nil
            var contentStart = index
            if contentStart < rawLine.endIndex {
                let ch = rawLine[contentStart]
                if ch == "•" || ch == "-" || ch == "*" {
                    bullet = String(ch)
                    contentStart = rawLine.index(after: contentStart)
                    // skip any spaces after bullet
                    while contentStart < rawLine.endIndex && rawLine[contentStart] == " " { contentStart = rawLine.index(after: contentStart) }
                }
            }

            let content = String(rawLine[contentStart...]).trimmingCharacters(in: .whitespaces)
            result.append(Line(level: max(0, level), bullet: bullet, content: content))
        }
        return result
    }
}

#Preview("Landing") {
    NavigationStack { LandingView() }
}


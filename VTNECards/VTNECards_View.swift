//
//  VTNECards_View.swift
//  VTNECards
//
//  Created by David Cardona on 11/16/25.
//

import SwiftUI
import UIKit

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
    @EnvironmentObject var dataSync: DataSyncManager

    // Categories to show
    var categoryFiles: [String] {
        if let manifest = dataSync.currentManifest {
            // ✅ Remote manifest is truth
            return manifest.jsonFiles
                .map { ( $0.path as NSString ).deletingPathExtension } // "Animal Care and Nursing Flashcards.json" -> "Animal Care and Nursing Flashcards"
                .sorted()
        } else {
            // ✅ No manifest yet (first launch offline, etc.) – fall back to bundle
            return bundleCategoryJSONFileNames()
        }
    }

    var body: some View {
        ZStack {
            List(categoryFiles, id: \.self) { fileName in
                NavigationLink("\(categoryDisplayName(forFile: fileName)) \(AnimalEmoji.random())") {
                    CategoryDetailView(categoryFile: fileName)
                }
                .ListRow()
            }
            .font(.system(size:20))
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Theme.pastelBackground.ignoresSafeArea())
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
                .ListRow()
                NavigationLink("Random Drill \(AnimalEmoji.random())") {
                    RandomDrillView(
                        cards: flashcards,
                        categoryTitle: categoryDisplayName(forFile: categoryFile),
                        categoryFile: categoryFile
                    )
                }
                .ListRow()
            }
            .font(.system(size:20))
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Theme.pastelBackground.ignoresSafeArea())
        }
        .navigationTitle("\(categoryFile)")
    }
}


struct CategoryFlashcardsView: View {
    let categoryFile: String
    private var flashcards: [Flashcard] {
        loadFlashcardsSafe(from: categoryFile)
    }

    // Use the same helper you already defined in VTNECards_System.swift
    private var imageProvider: (String) -> Image? {
        makeImageProvider(forCategoryFile: categoryFile)
    }

    var body: some View {
        ZStack {
            List(flashcards, id: \.title) { flashcard in
                NavigationLink {
                    FlashcardView(flashcard: flashcard, categoryFile: categoryFile)
                } label: {
                    FlashcardRowTitleView(
                        text: flashcard.title,
                        imageProvider: imageProvider
                    )
                }
                .ListRow()
            }
            .font(.system(size: 20))
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Theme.pastelBackground.ignoresSafeArea())
        }
        .navigationTitle(categoryFile)
    }
}


struct RandomDrillView: View {
    let cards: [Flashcard]
    let categoryTitle: String
    let categoryFile: String
    let imageProvider: (String) -> Image?
    let uiImageProvider: (String) -> UIImage?

    @State private var currentIndex: Int = 0
    @State private var showingDetail: Bool = false
    @State private var remainingIndices: [Int] = []

    @State private var zoomImageName: String?

    init(cards: [Flashcard], categoryTitle: String, categoryFile: String) {
        self.cards = cards
        self.categoryTitle = categoryTitle
        self.categoryFile = categoryFile
        self.imageProvider = makeImageProvider(forCategoryFile: categoryFile)
        self.uiImageProvider = makeUIImageProvider(forCategoryFile: categoryFile)
    }

    var body: some View {
        ZStack(alignment: .top) {
            Theme.pastelBackground.ignoresSafeArea()

            VStack(alignment: .leading) {
                ZStack {
                    cardView(for: cards[currentIndex])
                        .id(currentIndex)
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
                    ThemedTitle(text: "\(categoryTitle)", enableEmoji: false)
                    Text("Random Drill")
                        .font(.subheadline)
                }
            }
        }
        .sheet(item: $zoomImageName) { name in
            if let uiImage = uiImageProvider(name) {
                ZoomableImageSheet(image: uiImage, title: name)
            } else {
                Text("Could not load image")
                    .padding()
            }
        }
    }

    @ViewBuilder
    private func cardView(for card: Flashcard) -> some View {
        VStack(alignment: .leading) {
            TitleWithImagesView(
                text: card.title,
                imageProvider: imageProvider,
                onImageTap: handleImageTap
            )

            if showingDetail {
                BulletListView(
                    text: card.content,
                    imageProvider: imageProvider,
                    onImageTap: handleImageTap
                )
            } else {
                Text("Tap to reveal detail")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 6)
            }
        }
        .Card()
    }

    private func handleImageTap(_ filename: String) {
        zoomImageName = filename
    }

    // MARK: - Logic

    private func startIfNeeded() {
        guard !cards.isEmpty else { return }
        prepareNewDeck(avoiding: nil)
        showingDetail = false
    }

    
    // Build a new shuffled deck of indices.
    // If `avoiding` is provided, try not to put that index first (to avoid immediate repeats between cycles).
    private func prepareNewDeck(avoiding indexToAvoid: Int? = nil) {
        guard !cards.isEmpty else { return }

        var indices = Array(cards.indices).shuffled()

        if let avoid = indexToAvoid,
           cards.count > 1,
           indices.first == avoid,
           let swapIndex = indices.firstIndex(where: { $0 != avoid }) {
            indices.swapAt(0, swapIndex)
        }

        currentIndex = indices.first ?? 0
        remainingIndices = Array(indices.dropFirst())
    }


    private func advance() {
        guard !cards.isEmpty else { return }

        if showingDetail {
            // We are on the back → go to the next *new* card in the deck
            if remainingIndices.isEmpty {
                // All cards in this cycle have been shown → start a new shuffled cycle
                let lastIndex = currentIndex
                prepareNewDeck(avoiding: lastIndex)
                withAnimation(.easeInOut) {
                    showingDetail = false  // new card starts on front
                    // currentIndex was set in prepareNewDeck
                }
            } else {
                let next = remainingIndices.removeFirst()
                withAnimation(.easeInOut) {
                    showingDetail = false  // new card starts on front
                    currentIndex = next    // triggers slide transition
                }
            }
        } else {
            // We are on the front → just reveal the detail, don't advance the deck
            withAnimation(.easeInOut) {
                showingDetail = true
            }
        }
    }

}


struct FlashcardView: View {
    let flashcard: Flashcard
    let categoryFile: String

    private var imageProvider: (String) -> Image? {
        makeImageProvider(forCategoryFile: categoryFile)
    }

    private var uiImageProvider: (String) -> UIImage? {
        makeUIImageProvider(forCategoryFile: categoryFile)
    }

    @State private var zoomImageName: String?   // <-- stays

    var body: some View {
        ZStack {
            VStack {
                VStack(alignment: .leading) {
                    TitleWithImagesView(
                        text: flashcard.title,
                        imageProvider: imageProvider,
                        onImageTap: handleImageTap
                    )

                    Spacer(minLength: 20)

                    BulletListView(
                        text: flashcard.content,
                        imageProvider: imageProvider,
                        onImageTap: handleImageTap
                    )
                }
                .Card()
            }
            .padding()
        }
        .background(Theme.pastelBackground.ignoresSafeArea())
        .toolbar {
            ToolbarItem(placement: .principal) {
                let (plainTitle, _) = parseTextAndImageTokens(flashcard.title)
                ThemedTitle(text: plainTitle, enableEmoji: false)
            }
        }
        .sheet(item: $zoomImageName) { name in
            if let uiImage = uiImageProvider(name) {
                ZoomableImageSheet(image: uiImage, title: name)
            } else {
                Text("Could not load image")
                    .padding()
            }
        }
    }

    private func handleImageTap(_ filename: String) {
        zoomImageName = filename
    }
}


struct FlashcardRowTitleView: View {
    let text: String
    let imageProvider: (String) -> Image?

    var body: some View {
        let (plainText, images) = parseTextAndImageTokens(text)

        HStack(spacing: 12) {
            // Thumbnail on the left if there is at least one image
            if let firstImageName = images.first,
               let image = imageProvider(firstImageName) {
                image
                    .resizable()
                    .scaledToFit()
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            } else if images.first != nil {
                // We had an [[image:...]] token but couldn't load it
                Image(systemName: "photo")
                    .frame(width: 44, height: 44)
                    .foregroundColor(.secondary)
            }

            VStack(alignment: .leading, spacing: 4) {
                if !plainText.isEmpty {
                    Text(plainText)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                } else if !images.isEmpty {
                    // Only image, no text – still show *something* textual as a label
                    Text("Image card")
                        .italic()
                        .foregroundColor(.secondary)
                } else {
                    // No text and no images – true fallback
                    Text("Untitled card")
                        .italic()
                        .foregroundColor(.secondary)
                }
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }
}


struct TitleWithImagesView: View {
    let text: String
    let imageProvider: (String) -> Image?
    let onImageTap: ((String) -> Void)?

    init(
        text: String,
        imageProvider: @escaping (String) -> Image?,
        onImageTap: ((String) -> Void)? = nil
    ) {
        self.text = text
        self.imageProvider = imageProvider
        self.onImageTap = onImageTap
    }

    var body: some View {
        let (plainText, images) = parseTextAndImageTokens(text)

        VStack(alignment: .leading, spacing: 8) {
            if !plainText.isEmpty {
                ThemedTitle(text: plainText, enableEmoji: false)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            ForEach(images, id: \.self) { filename in
                if let image = imageProvider(filename) {
                    image
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity)      // ⬅️ full width of container
                        .contentShape(Rectangle())        // ⬅️ make whole area tappable
                        .onTapGesture {
                            onImageTap?(filename)
                        }
                } else {
                    Text("[Image not found: \(filename)]")
                        .font(.footnote)
                        .foregroundColor(.red)
                }
            }
        }
    }
}


struct BulletListView: View {
    let text: String
    let imageProvider: (String) -> Image?
    let onImageTap: ((String) -> Void)?

    private struct Line: Identifiable {
        let id = UUID()
        let level: Int
        let bullet: String?
        let content: String
        let images: [String]
    }

    private let spacesPerIndentLevel = 4
    private let indentUnit: CGFloat = 16
    private let bulletColumnWidth: CGFloat = 14

    init(
        text: String,
        imageProvider: @escaping (String) -> Image? = { filename in
            let baseName = (filename as NSString).deletingPathExtension
            return Image(baseName)
        },
        onImageTap: ((String) -> Void)? = nil
    ) {
        self.text = text
        self.imageProvider = imageProvider
        self.onImageTap = onImageTap
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(parseLines(from: text)) { line in
                    HStack(alignment: .top, spacing: 8) {
                        if let bullet = line.bullet {
                            Text(bullet)
                                .foregroundStyle(Theme.charcoal)
                                .frame(width: bulletColumnWidth, alignment: .trailing)
                        } else {
                            Color.clear
                                .frame(width: bulletColumnWidth)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            if !line.content.isEmpty {
                                Text(line.content)
                                    .foregroundStyle(Theme.charcoal)
                                    .multilineTextAlignment(.leading)
                                    .fixedSize(horizontal: false, vertical: true)
                            }

                            // Images for this line
                            ForEach(line.images, id: \.self) { filename in
                                if let image = imageProvider(filename) {
                                    image
                                        .resizable()
                                        .scaledToFit()
                                        .frame(maxWidth: .infinity)      // ⬅️ full width
                                        .contentShape(Rectangle())
                                        .onTapGesture {
                                            onImageTap?(filename)
                                        }
                                } else {
                                    Text("[Image not found: \(filename)]")
                                        .font(.footnote)
                                        .foregroundColor(.red)
                                }
                            }
                        }
                    }
                    .padding(.leading, CGFloat(line.level) * indentUnit)
                }
                .font(.system(size: 20))
                .padding(.vertical, 2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Parsing

    private func parseLines(from raw: String) -> [Line] {
        var result: [Line] = []
        for rawLine in raw.components(separatedBy: .newlines) {
            let trimmedRight = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            // Skip empty lines but preserve paragraph breaks as blank entries
            if trimmedRight.isEmpty {
                result.append(Line(level: 0, bullet: nil, content: "", images: []))
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
                    while contentStart < rawLine.endIndex && rawLine[contentStart] == " " {
                        contentStart = rawLine.index(after: contentStart)
                    }
                }
            }

            let contentRaw = String(rawLine[contentStart...]).trimmingCharacters(in: .whitespaces)
            let (plainText, images) = parseContentAndImages(from: contentRaw)

            result.append(
                Line(
                    level: max(0, level),
                    bullet: bullet,
                    content: plainText,
                    images: images
                )
            )
        }
        return result
    }

    /// Extracts plain text (with [[image:...]] removed) and a list of image filenames.
    private func parseContentAndImages(from text: String) -> (plainText: String, images: [String]) {
        parseTextAndImageTokens(text)
    }

}


// MARK: - Zoomable Image Infrastructure

struct ZoomableScrollView<Content: View>: UIViewRepresentable {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()

        scrollView.delegate = context.coordinator
        scrollView.maximumZoomScale = 5.0
        scrollView.minimumZoomScale = 1.0
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.bouncesZoom = true
        scrollView.backgroundColor = .black

        let hostedView = UIHostingController(rootView: content).view!
        hostedView.translatesAutoresizingMaskIntoConstraints = false
        hostedView.backgroundColor = .black

        scrollView.addSubview(hostedView)

        NSLayoutConstraint.activate([
            hostedView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            hostedView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            hostedView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            hostedView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            hostedView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            hostedView.heightAnchor.constraint(equalTo: scrollView.heightAnchor)
        ])

        return scrollView
    }

    func updateUIView(_ uiView: UIScrollView, context: Context) {
        // static content – nothing special to update
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator: NSObject, UIScrollViewDelegate {
        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            scrollView.subviews.first
        }
    }
}

struct ZoomableImageSheet: View {
    let image: UIImage
    let title: String

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZoomableScrollView {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .background(Color.black)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .foregroundColor(.white)
                }
            }
        }
    }
}

extension String: @retroactive Identifiable {
    public var id: String { self }
}


#Preview("Landing") {
    LandingView()
        .environmentObject(DataSyncManager.shared)
}

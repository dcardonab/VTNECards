import SwiftUI

// MARK: - Miffy Theme
struct MiffyTheme {
    // Palette (Miffy-inspired pastels and neutrals)
    static let cream = Color(red: 0.98, green: 0.97, blue: 0.93)
    static let softBlue = Color(red: 0.60, green: 0.74, blue: 0.90)
    static let softOrange = Color(red: 0.98, green: 0.74, blue: 0.47)
    static let charcoal = Color(red: 0.17, green: 0.18, blue: 0.20)

    static let accent = softOrange
    static let tint = softBlue

    // Background
    static var pastelBackground: some View {
        LinearGradient(
            gradient: Gradient(colors: [cream, softBlue.opacity(0.12)]),
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

// MARK: - Screen Background
struct ScreenBackground: View {
    var body: some View {
        MiffyTheme.pastelBackground
            .ignoresSafeArea()
    }
}

// MARK: - Card Style
private struct CardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.white.opacity(0.9))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(MiffyTheme.softBlue.opacity(0.25), lineWidth: 1)
                    )
            )
            .shadow(color: MiffyTheme.softBlue.opacity(0.15), radius: 10, x: 0, y: 6)
            .foregroundStyle(.primary)
    }
}

extension View {
    func miffyCard() -> some View { modifier(CardStyle()) }
}

// MARK: - List Row Style
private struct ThemedListRow: ViewModifier {
    func body(content: Content) -> some View {
        content
            .listRowBackground(Color.white.opacity(0.6))
            .listRowSeparatorTint(MiffyTheme.softBlue.opacity(0.25))
    }
}

extension View {
    func miffyListRow() -> some View { modifier(ThemedListRow()) }
}

// MARK: - Themed Title
struct ThemedTitle: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.largeTitle)
            .fontWeight(.bold)
            .foregroundStyle(MiffyTheme.charcoal)
    }
}

// MARK: - Previews
#Preview("Miffy Theme Components") {
    ZStack {
        ScreenBackground()
        VStack(spacing: 20) {
            ThemedTitle(text: "Miffy Theme 🐰")
            VStack(alignment: .leading, spacing: 8) {
                Text("This is a card styled area with soft edges and a gentle shadow.")
                Text("Use it for flashcards, drills, and highlights.")
                    .foregroundStyle(.secondary)
            }
            .miffyCard()
        }
        .padding()
    }
}

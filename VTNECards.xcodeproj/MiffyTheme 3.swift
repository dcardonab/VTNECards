import SwiftUI

// MARK: - Miffy Theme
struct MiffyTheme {
    // Palette (Miffy-inspired pastels and neutrals)
    static let cream = Color(red: 0.99, green: 0.98, blue: 0.95)         // softer cream
    static let softBlue = Color(red: 0.60, green: 0.74, blue: 0.90)       // Miffy blue
    static let helloKittyPink = Color(red: 1.00, green: 0.58, blue: 0.74) // subtle HK influence
    static let charcoal = Color(red: 0.15, green: 0.16, blue: 0.18)

    static let accent = helloKittyPink.opacity(0.85)
    static let tint = softBlue

    // Background
    static var pastelBackground: some View {
        LinearGradient(
            colors: [
                cream,
                softBlue.opacity(0.10),
                helloKittyPink.opacity(0.08)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
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
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(MiffyTheme.softBlue.opacity(0.35), lineWidth: 1.25)
                    )
            )
            .shadow(color: MiffyTheme.softBlue.opacity(0.18), radius: 12, x: 0, y: 8)
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
            .listRowBackground(Color.white.opacity(0.75))
            .listRowSeparatorTint(MiffyTheme.accent.opacity(0.35))
    }
}

extension View {
    func miffyListRow() -> some View { modifier(ThemedListRow()) }
}

// MARK: - Themed Title
struct ThemedTitle: View {
    let text: String
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(text)
                .font(.system(size: 34, weight: .heavy, design: .rounded))
                .foregroundStyle(MiffyTheme.charcoal)
            Text("🎀")
                .font(.system(size: 26))
                .foregroundStyle(MiffyTheme.accent)
                .opacity(0.85)
        }
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

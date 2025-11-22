import SwiftUI

// MARK: -  Theme
struct Theme {
    // Palette (-inspired pastels and neutrals)
    static let cream = Color(red: 0.99, green: 0.98, blue: 0.95)         // softer cream
    static let softBlue = Color(red: 0.60, green: 0.74, blue: 0.90)       //  blue
    static let pink = Color(red: 1.00, green: 0.58, blue: 0.74) // subtle HK influence
    static let charcoal = Color(red: 0.15, green: 0.16, blue: 0.18)

    static let accent = pink.opacity(0.85)
    static let tint = softBlue

    // Background
    static var pastelBackground: some View {
        LinearGradient(
            colors: [
                softBlue.opacity(0.6),
                cream,
                pink.opacity(0.38)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - Emoji Helper
struct AnimalEmoji {
    // Avoid using only rabbits; include a variety of cute animals
    static let options: [String] = ["🐶","🐱","🐭","🐹","🐰","🦊","🐻","🐨","🐼","🐯","🦁","🐷","🐮","🐸","🐵"]
    static func random() -> String { options.randomElement() ?? "🐾" }
}

// MARK: - Card Style
private struct CardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(Color.white)
                    .stroke(Theme.softBlue.opacity(0.35), lineWidth: 1.25)
            )
            .shadow(color: Theme.softBlue.opacity(0.18), radius: 12, x: 0, y: 8)
            .foregroundStyle(Theme.charcoal)
    }
}

extension View {
    func Card() -> some View { modifier(CardStyle()) }
}

// MARK: - List Row Style
private struct ThemedListRow: ViewModifier {
    func body(content: Content) -> some View {
        content
            .listRowBackground(Color.white.opacity(0.75))
            .listRowSeparatorTint(Theme.accent.opacity(0.35))
    }
}

extension View {
    func ListRow() -> some View { modifier(ThemedListRow()) }
}

// MARK: - Themed Title
struct ThemedTitle: View {
    let text: String
    let enableEmoji: Bool
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(text)
                .font(.title2)
                .fontWeight(.heavy)
                .fontDesign(.rounded)
                .foregroundStyle(Theme.charcoal)
            if (enableEmoji) {
                Text(AnimalEmoji.random())
                    .font(.system(size: 26))
                    .opacity(0.95)
            }
        }
    }
}

// MARK: - Previews
#Preview(" Theme Components") {
    ZStack {
        Theme.pastelBackground
            .ignoresSafeArea()
        VStack(spacing: 20) {
            ThemedTitle(text: " Theme", enableEmoji: true)
            VStack(alignment: .leading, spacing: 8) {
                Text("This is a card styled area with soft edges and a gentle shadow.")
                Text("Use it for flashcards, drills, and highlights.")
                    .foregroundStyle(.secondary)
            }
            .Card()
        }
        .padding()
    }
}


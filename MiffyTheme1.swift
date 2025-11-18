import SwiftUI

struct MiffyTheme {
    static let cream = Color(red: 0.98, green: 0.97, blue: 0.93)
    static let softBlue = Color(red: 0.60, green: 0.74, blue: 0.90)
    static let softOrange = Color(red: 0.98, green: 0.74, blue: 0.47)
    static let charcoal = Color(red: 0.17, green: 0.18, blue: 0.20)
    
    static var accent: Color { softOrange }
    static var tint: Color { softBlue }
    
    static var pastelBackground: some View {
        LinearGradient(
            gradient: Gradient(colors: [cream, softBlue.opacity(0.12)]),
            startPoint: .top,
            endPoint: .bottom
        )
    }
    
    struct CardStyle: ViewModifier {
        func body(content: Content) -> some View {
            content
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.white.opacity(0.9))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(softBlue.opacity(0.25), lineWidth: 1)
                        )
                )
                .shadow(color: softBlue.opacity(0.15), radius: 10, y: 6)
                .foregroundStyle(.primary)
        }
    }
    
    struct ThemedListRow: ViewModifier {
        func body(content: Content) -> some View {
            content
                .listRowBackground(Color.white.opacity(0.6))
                .listRowSeparatorTint(softBlue.opacity(0.25))
        }
    }
}

extension View {
    func miffyCard() -> some View {
        modifier(MiffyTheme.CardStyle())
    }
    
    func miffyListRow() -> some View {
        modifier(MiffyTheme.ThemedListRow())
    }
}

struct ScreenBackground: View {
    var body: some View {
        MiffyTheme.pastelBackground
            .ignoresSafeArea()
    }
}

struct ThemedTitle: View {
    let text: String
    
    var body: some View {
        Text(text)
            .font(.largeTitle)
            .fontWeight(.bold)
            .foregroundStyle(MiffyTheme.charcoal)
    }
}

struct MiffyTheme_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            ScreenBackground()
            VStack(spacing: 24) {
                ThemedTitle(text: "Miffy Theme")
                Text("This is a card styled with MiffyTheme.")
                    .miffyCard()
                List {
                    ForEach(1..<4) { i in
                        Text("List Row \(i)")
                            .miffyListRow()
                    }
                }
                .frame(height: 150)
                .listStyle(.insetGrouped)
                .background(Color.clear)
            }
            .padding()
        }
    }
}

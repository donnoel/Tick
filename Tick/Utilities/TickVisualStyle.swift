import SwiftUI

enum TickPalette {
    static let appBackground = Color(.systemGroupedBackground)
    static let cardBackground = Color(.secondarySystemGroupedBackground)
    static let primaryAction = Color.blue
    static let running = Color.orange
    static let locationReady = Color.green
}

enum TickProjectAccent {
    private static let colors: [Color] = [
        .purple,
        .pink,
        .teal,
        .orange,
        .indigo,
        .mint
    ]

    static func color(for projectID: UUID) -> Color {
        colors[index(for: projectID.uuidString)]
    }

    static func color(for projectName: String) -> Color {
        colors[index(for: projectName)]
    }

    static func index(for seed: String) -> Int {
        let value = seed.unicodeScalars.reduce(0) { partialResult, scalar in
            partialResult &+ Int(scalar.value)
        }

        return value % colors.count
    }
}

struct TickCardBackground: ViewModifier {
    var tint: Color = Color.accentColor
    var isHighlighted = false

    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: 14)
                    .fill(TickPalette.cardBackground)
                    .overlay(alignment: .topLeading) {
                        RoundedRectangle(cornerRadius: 14)
                            .fill(tint.opacity(isHighlighted ? 0.18 : 0.08))
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(tint.opacity(isHighlighted ? 0.35 : 0.16), lineWidth: 1)
                    }
            }
    }
}

extension View {
    func tickCard(tint: Color = Color.accentColor, isHighlighted: Bool = false) -> some View {
        modifier(TickCardBackground(tint: tint, isHighlighted: isHighlighted))
    }
}

struct TickProjectBadge: View {
    let color: Color
    var systemImage = "circle.fill"

    var body: some View {
        ZStack {
            Circle()
                .fill(color.opacity(0.18))

            Image(systemName: systemImage)
                .font(.caption.weight(.bold))
                .foregroundStyle(color)
        }
        .frame(width: 34, height: 34)
        .accessibilityHidden(true)
    }
}

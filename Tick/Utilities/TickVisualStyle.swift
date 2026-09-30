import SwiftUI

enum TickPalette {
    static let appBackground = Color(.systemGroupedBackground)
    static let cardBackground = Color(.secondarySystemGroupedBackground)
    static let primaryAction = Color.blue
    static let running = Color.indigo
    static let locationReady = Color.green
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

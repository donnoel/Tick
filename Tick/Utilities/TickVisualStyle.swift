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
        .blue,
        .pink,
        .orange,
        .purple,
        .green,
        .indigo,
        .mint,
        .red,
        .cyan,
        .yellow,
        .teal,
        .brown
    ]

    static func color(for projectID: UUID) -> Color {
        colors[index(for: projectID)]
    }

    static func index(for projectID: UUID) -> Int {
        index(for: projectID.uuidString)
    }

    static func index(for seed: String) -> Int {
        let normalizedSeed = seed.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        var hash: UInt64 = 14_695_981_039_346_656_037

        for scalar in normalizedSeed.unicodeScalars {
            hash ^= UInt64(scalar.value)
            hash = hash &* 1_099_511_628_211
        }

        hash ^= hash >> 33
        hash = hash &* 0xff51afd7ed558ccd
        hash ^= hash >> 33

        return Int(hash % UInt64(colors.count))
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

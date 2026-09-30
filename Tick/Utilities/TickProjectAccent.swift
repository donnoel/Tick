import SwiftUI

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

    static func color(for projectID: UUID, among projectIDs: [UUID]) -> Color {
        let assignedIndex = index(for: projectID, among: projectIDs)

        if assignedIndex < colors.count {
            return colors[assignedIndex]
        }

        return Color(
            hue: Double((assignedIndex * 47) % 360) / 360,
            saturation: 0.72,
            brightness: 0.82
        )
    }

    static func index(for projectID: UUID) -> Int {
        index(for: projectID.uuidString)
    }

    static func index(for projectID: UUID, among projectIDs: [UUID]) -> Int {
        var uniqueProjectIDs: [UUID] = []

        for candidateID in projectIDs + [projectID] where !uniqueProjectIDs.contains(candidateID) {
            uniqueProjectIDs.append(candidateID)
        }

        return uniqueProjectIDs.firstIndex(of: projectID) ?? index(for: projectID)
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

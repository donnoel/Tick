import Foundation

nonisolated struct TickProject: Codable, Equatable, Hashable, Identifiable {
    let id: UUID
    var name: String
    let createdAt: Date
    var isArchived: Bool
    var sortOrder: Double

    init(
        id: UUID = UUID(),
        name: String,
        createdAt: Date = .now,
        isArchived: Bool = false,
        sortOrder: Double? = nil
    ) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.isArchived = isArchived
        self.sortOrder = sortOrder ?? createdAt.timeIntervalSinceReferenceDate
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        isArchived = try container.decodeIfPresent(Bool.self, forKey: .isArchived) ?? false
        sortOrder = try container.decodeIfPresent(Double.self, forKey: .sortOrder) ?? createdAt.timeIntervalSinceReferenceDate
    }

    static func sortedByDisplayOrder(_ projects: [TickProject]) -> [TickProject] {
        projects.sorted { lhs, rhs in
            if lhs.sortOrder == rhs.sortOrder {
                return lhs.createdAt < rhs.createdAt
            }

            return lhs.sortOrder < rhs.sortOrder
        }
    }

    static func sortedByActivity(
        _ projects: [TickProject],
        durationsByProjectID: [TickProject.ID: TimeInterval]
    ) -> [TickProject] {
        sortedByDisplayOrder(projects).sorted { lhs, rhs in
            let lhsDuration = durationsByProjectID[lhs.id] ?? 0
            let rhsDuration = durationsByProjectID[rhs.id] ?? 0

            if lhsDuration == rhsDuration {
                if lhs.sortOrder == rhs.sortOrder {
                    return lhs.createdAt < rhs.createdAt
                }

                return lhs.sortOrder < rhs.sortOrder
            }

            return lhsDuration > rhsDuration
        }
    }
}

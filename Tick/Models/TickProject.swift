import Foundation

nonisolated struct TickProject: Codable, Equatable, Hashable, Identifiable {
    let id: UUID
    var name: String
    let createdAt: Date
    var isArchived: Bool

    init(
        id: UUID = UUID(),
        name: String,
        createdAt: Date = .now,
        isArchived: Bool = false
    ) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.isArchived = isArchived
    }
}

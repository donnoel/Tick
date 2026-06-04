import Foundation

nonisolated struct VoiceMemo: Codable, Equatable, Hashable, Identifiable {
    let id: UUID
    var projectID: TickProject.ID
    var title: String
    let fileName: String
    var duration: TimeInterval
    let createdAt: Date

    init(
        id: UUID = UUID(),
        projectID: TickProject.ID,
        title: String,
        fileName: String? = nil,
        duration: TimeInterval,
        createdAt: Date = .now
    ) {
        self.id = id
        self.projectID = projectID
        self.title = title
        self.fileName = fileName ?? "\(id.uuidString).m4a"
        self.duration = duration
        self.createdAt = createdAt
    }
}

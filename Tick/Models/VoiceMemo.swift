import Foundation

nonisolated struct VoiceMemo: Codable, Equatable, Hashable, Identifiable {
    let id: UUID
    var projectID: TickProject.ID
    var title: String
    let fileName: String
    var duration: TimeInterval
    let createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        projectID: TickProject.ID,
        title: String,
        fileName: String? = nil,
        duration: TimeInterval,
        createdAt: Date = .now,
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.projectID = projectID
        self.title = title
        self.fileName = fileName ?? "\(id.uuidString).m4a"
        self.duration = duration
        self.createdAt = createdAt
        self.updatedAt = updatedAt ?? createdAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        projectID = try container.decode(TickProject.ID.self, forKey: .projectID)
        title = try container.decode(String.self, forKey: .title)
        fileName = try container.decode(String.self, forKey: .fileName)
        duration = try container.decode(TimeInterval.self, forKey: .duration)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? createdAt
    }
}

nonisolated struct VoiceMemoDeletion: Codable, Equatable, Hashable, Identifiable {
    let id: VoiceMemo.ID
    var fileName: String?
    var deletedAt: Date

    init(id: VoiceMemo.ID, fileName: String? = nil, deletedAt: Date = .now) {
        self.id = id
        self.fileName = fileName
        self.deletedAt = deletedAt
    }
}

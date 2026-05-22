import Foundation

nonisolated struct TickStorageSnapshot: Codable, Equatable {
    var projects: [TickProject]
    var sessions: [TimeSession]
    var autoTickRules: [AutoTickRule]

    static let empty = TickStorageSnapshot(projects: [], sessions: [], autoTickRules: [])

    init(projects: [TickProject], sessions: [TimeSession], autoTickRules: [AutoTickRule] = []) {
        self.projects = projects
        self.sessions = sessions
        self.autoTickRules = autoTickRules
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        projects = try container.decodeIfPresent([TickProject].self, forKey: .projects) ?? []
        sessions = try container.decodeIfPresent([TimeSession].self, forKey: .sessions) ?? []
        autoTickRules = try container.decodeIfPresent([AutoTickRule].self, forKey: .autoTickRules) ?? []
    }
}

import Foundation

nonisolated struct TickWidgetStorageSnapshot: Codable, Equatable {
    var projects: [TickWidgetStoredProject]
    var sessions: [TickWidgetStoredSession]
    var autoTickRules: [TickWidgetStoredAutoTickRule]

    static let empty = TickWidgetStorageSnapshot(projects: [], sessions: [], autoTickRules: [])

    init(
        projects: [TickWidgetStoredProject],
        sessions: [TickWidgetStoredSession],
        autoTickRules: [TickWidgetStoredAutoTickRule] = []
    ) {
        self.projects = projects
        self.sessions = sessions
        self.autoTickRules = autoTickRules
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        projects = try container.decodeIfPresent([TickWidgetStoredProject].self, forKey: .projects) ?? []
        sessions = try container.decodeIfPresent([TickWidgetStoredSession].self, forKey: .sessions) ?? []
        autoTickRules = try container.decodeIfPresent([TickWidgetStoredAutoTickRule].self, forKey: .autoTickRules) ?? []
    }
}

nonisolated struct TickWidgetStoredProject: Codable, Equatable, Identifiable {
    let id: UUID
    var name: String
    var createdAt: Date
    var isArchived: Bool
}

nonisolated struct TickWidgetStoredSession: Codable, Equatable, Identifiable {
    let id: UUID
    var projectID: UUID
    var title: String
    var notes: String
    var startedAt: Date?
    var endedAt: Date?
    var manualDuration: TimeInterval?
    var entrySource: String
    var autoTickRuleID: UUID?
    var createdAt: Date

    var isActive: Bool {
        (entrySource == "timer" || entrySource == "autoLocation") &&
            startedAt != nil &&
            endedAt == nil &&
            manualDuration == nil
    }

    var referenceDate: Date {
        startedAt ?? endedAt ?? createdAt
    }

    func duration(at date: Date) -> TimeInterval {
        if let manualDuration {
            return max(0, manualDuration)
        }

        guard let startedAt else {
            return 0
        }

        if let endedAt {
            return max(0, endedAt.timeIntervalSince(startedAt))
        }

        return max(0, date.timeIntervalSince(startedAt))
    }
}

nonisolated struct TickWidgetStoredAutoTickRule: Codable, Equatable, Identifiable {
    let id: UUID
    var projectID: UUID
    var name: String
    var latitude: Double
    var longitude: Double
    var radiusMeters: Double
    var startsOnArrival: Bool
    var stopsOnDeparture: Bool
    var isEnabled: Bool
    var createdAt: Date
}

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
    var sortOrder: Double

    init(
        id: UUID,
        name: String,
        createdAt: Date,
        isArchived: Bool,
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
}

nonisolated struct TickWidgetStoredSession: Codable, Equatable, Identifiable {
    let id: UUID
    var projectID: UUID
    var title: String
    var notes: String
    var startedAt: Date?
    var endedAt: Date?
    var manualDuration: TimeInterval?
    var pausedAt: Date?
    var accumulatedPausedDuration: TimeInterval?
    var entrySource: String
    var autoTickRuleID: UUID?
    var createdAt: Date

    init(
        id: UUID,
        projectID: UUID,
        title: String,
        notes: String,
        startedAt: Date?,
        endedAt: Date?,
        manualDuration: TimeInterval?,
        pausedAt: Date? = nil,
        accumulatedPausedDuration: TimeInterval? = nil,
        entrySource: String,
        autoTickRuleID: UUID?,
        createdAt: Date
    ) {
        self.id = id
        self.projectID = projectID
        self.title = title
        self.notes = notes
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.manualDuration = manualDuration
        self.pausedAt = pausedAt
        self.accumulatedPausedDuration = accumulatedPausedDuration
        self.entrySource = entrySource
        self.autoTickRuleID = autoTickRuleID
        self.createdAt = createdAt
    }

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

        let effectiveEndDate = endedAt ?? pausedAt ?? date
        let elapsedDuration = effectiveEndDate.timeIntervalSince(startedAt)
        return max(0, elapsedDuration - (accumulatedPausedDuration ?? 0))
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

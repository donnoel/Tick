import Foundation

nonisolated public struct TickWidgetStorageSnapshot: Codable, Equatable, Sendable {
    public var projects: [TickWidgetStoredProject]
    public var sessions: [TickWidgetStoredSession]
    public var autoTickRules: [TickWidgetStoredAutoTickRule]

    public static let empty = TickWidgetStorageSnapshot(projects: [], sessions: [], autoTickRules: [])

    public init(
        projects: [TickWidgetStoredProject],
        sessions: [TickWidgetStoredSession],
        autoTickRules: [TickWidgetStoredAutoTickRule] = []
    ) {
        self.projects = projects
        self.sessions = sessions
        self.autoTickRules = autoTickRules
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        projects = try container.decodeIfPresent([TickWidgetStoredProject].self, forKey: .projects) ?? []
        sessions = try container.decodeIfPresent([TickWidgetStoredSession].self, forKey: .sessions) ?? []
        autoTickRules = try container.decodeIfPresent([TickWidgetStoredAutoTickRule].self, forKey: .autoTickRules) ?? []
    }
}

nonisolated public struct TickWidgetStoredProject: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public var name: String
    public var createdAt: Date
    public var isArchived: Bool
    public var sortOrder: Double

    public init(
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

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        isArchived = try container.decodeIfPresent(Bool.self, forKey: .isArchived) ?? false
        sortOrder = try container.decodeIfPresent(Double.self, forKey: .sortOrder) ?? createdAt.timeIntervalSinceReferenceDate
    }

    public static func activeSortedByDisplayOrder(_ projects: [TickWidgetStoredProject]) -> [TickWidgetStoredProject] {
        projects
            .filter { !$0.isArchived }
            .sorted { lhs, rhs in
                if lhs.sortOrder == rhs.sortOrder {
                    return lhs.createdAt < rhs.createdAt
                }

                return lhs.sortOrder < rhs.sortOrder
            }
    }
}

nonisolated public struct TickWidgetStoredSession: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public var projectID: UUID
    public var title: String
    public var notes: String
    public var startedAt: Date?
    public var endedAt: Date?
    public var manualDuration: TimeInterval?
    public var pausedAt: Date?
    public var accumulatedPausedDuration: TimeInterval?
    public var entrySource: String
    public var autoTickRuleID: UUID?
    public var createdAt: Date

    public init(
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

    public var isActive: Bool {
        (entrySource == "timer" || entrySource == "autoLocation") &&
            startedAt != nil &&
            endedAt == nil &&
            manualDuration == nil
    }

    public var referenceDate: Date {
        startedAt ?? endedAt ?? createdAt
    }

    public func duration(at date: Date) -> TimeInterval {
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

nonisolated public struct TickWidgetStoredAutoTickRule: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public var projectID: UUID
    public var name: String
    public var latitude: Double
    public var longitude: Double
    public var radiusMeters: Double
    public var startsOnArrival: Bool
    public var stopsOnDeparture: Bool
    public var isEnabled: Bool
    public var createdAt: Date
}

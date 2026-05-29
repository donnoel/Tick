import Foundation

nonisolated enum SessionEntrySource: String, Codable, CaseIterable, Equatable, Hashable, Identifiable {
    case timer
    case manual
    case autoLocation

    var id: String { rawValue }
}

nonisolated struct TimeSession: Codable, Equatable, Hashable, Identifiable {
    let id: UUID
    var projectID: TickProject.ID
    var title: String
    var notes: String
    var startedAt: Date?
    var endedAt: Date?
    var manualDuration: TimeInterval?
    var pausedAt: Date?
    var accumulatedPausedDuration: TimeInterval?
    var entrySource: SessionEntrySource
    var autoTickRuleID: AutoTickRule.ID?
    let createdAt: Date

    init(
        id: UUID = UUID(),
        projectID: TickProject.ID,
        title: String,
        notes: String,
        startedAt: Date?,
        endedAt: Date?,
        manualDuration: TimeInterval?,
        pausedAt: Date? = nil,
        accumulatedPausedDuration: TimeInterval? = nil,
        entrySource: SessionEntrySource,
        autoTickRuleID: AutoTickRule.ID? = nil,
        createdAt: Date = .now
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
        (entrySource == .timer || entrySource == .autoLocation) &&
            startedAt != nil &&
            endedAt == nil &&
            manualDuration == nil
    }

    var isPaused: Bool {
        isActive && pausedAt != nil
    }

    var referenceDate: Date {
        startedAt ?? endedAt ?? createdAt
    }

    func duration(at date: Date = .now) -> TimeInterval {
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

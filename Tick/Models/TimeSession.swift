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

        if let endedAt {
            return max(0, endedAt.timeIntervalSince(startedAt))
        }

        return max(0, date.timeIntervalSince(startedAt))
    }
}

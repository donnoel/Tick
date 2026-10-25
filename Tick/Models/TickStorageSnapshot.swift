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

extension TickStorageSnapshot {
    nonisolated static func mergingEdits(
        base: TickStorageSnapshot,
        proposed: TickStorageSnapshot,
        latest: TickStorageSnapshot
    ) -> TickStorageSnapshot {
        TickStorageSnapshot(
            projects: mergeRecords(base: base.projects, proposed: proposed.projects, latest: latest.projects),
            sessions: mergeRecords(
                base: base.sessions,
                proposed: proposed.sessions,
                latest: latest.sessions,
                mergeChanged: mergeSession
            ),
            autoTickRules: mergeRecords(
                base: base.autoTickRules,
                proposed: proposed.autoTickRules,
                latest: latest.autoTickRules
            )
        )
    }

    private nonisolated static func mergeRecords<Record: Identifiable & Equatable>(
        base: [Record],
        proposed: [Record],
        latest: [Record],
        mergeChanged: ((Record, Record, Record) -> Record)? = nil
    ) -> [Record] where Record.ID: Hashable {
        let baseByID = Dictionary(base.map { ($0.id, $0) }, uniquingKeysWith: { _, newest in newest })
        let proposedByID = Dictionary(proposed.map { ($0.id, $0) }, uniquingKeysWith: { _, newest in newest })
        let latestByID = Dictionary(latest.map { ($0.id, $0) }, uniquingKeysWith: { _, newest in newest })

        var result = latest.filter { record in
            baseByID[record.id] == nil || proposedByID[record.id] != nil
        }
        for record in proposed {
            guard let original = baseByID[record.id] else {
                if latestByID[record.id] == nil { result.append(record) }
                continue
            }
            guard record != original,
                  let current = latestByID[record.id],
                  let index = result.firstIndex(where: { $0.id == record.id }) else {
                continue // A concurrent deletion wins over a stale edit.
            }
            result[index] = mergeChanged?(original, record, current) ?? record
        }
        return result
    }

    private nonisolated static func mergeSession(
        base: TimeSession,
        proposed: TimeSession,
        latest: TimeSession
    ) -> TimeSession {
        var result = latest
        if proposed.projectID != base.projectID { result.projectID = proposed.projectID }
        if proposed.title != base.title { result.title = proposed.title }
        if proposed.notes != base.notes { result.notes = proposed.notes }
        if proposed.startedAt != base.startedAt { result.startedAt = proposed.startedAt }
        if proposed.manualDuration != base.manualDuration { result.manualDuration = proposed.manualDuration }
        if proposed.entrySource != base.entrySource { result.entrySource = proposed.entrySource }
        if proposed.autoTickRuleID != base.autoTickRuleID { result.autoTickRuleID = proposed.autoTickRuleID }
        if latest.endedAt == base.endedAt, proposed.endedAt != base.endedAt {
            result.endedAt = proposed.endedAt
        }
        if latest.pausedAt == base.pausedAt, proposed.pausedAt != base.pausedAt {
            result.pausedAt = proposed.pausedAt
        }
        if latest.accumulatedPausedDuration == base.accumulatedPausedDuration,
           proposed.accumulatedPausedDuration != base.accumulatedPausedDuration {
            result.accumulatedPausedDuration = proposed.accumulatedPausedDuration
        }
        if result.endedAt != nil { result.pausedAt = nil }
        return result
    }
}

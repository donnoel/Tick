import Foundation

/// Cloud tombstones prevent an offline device from restoring deleted records.
nonisolated struct TickCloudPayload: Codable, Equatable, Sendable {
    var snapshot: TickWidgetStorageSnapshot
    var deletedProjects: Set<UUID> = []
    var deletedSessions: Set<UUID> = []
    var deletedRules: Set<UUID> = []
}

nonisolated struct TickCloudCheckpoint: Codable, Sendable {
    var accountID: String
    var acknowledged: TickCloudPayload?
    var confirmedAt: Date? = nil
}

nonisolated enum TickCloudMerge {
    static func resolve(
        base: TickWidgetStorageSnapshot,
        local: TickWidgetStorageSnapshot,
        remote: TickCloudPayload
    ) -> TickCloudPayload {
        var result = remote
        result.deletedProjects.formUnion(Set(base.projects.map(\.id)).subtracting(local.projects.map(\.id)))
        result.deletedSessions.formUnion(Set(base.sessions.map(\.id)).subtracting(local.sessions.map(\.id)))
        result.deletedRules.formUnion(Set(base.autoTickRules.map(\.id)).subtracting(local.autoTickRules.map(\.id)))

        let projects = merge(base.projects, local.projects, remote.snapshot.projects)
            .filter { !result.deletedProjects.contains($0.id) }
        let projectIDs = Set(projects.map(\.id))
        var sessions = merge(base.sessions, local.sessions, remote.snapshot.sessions)
            .filter { !result.deletedSessions.contains($0.id) && projectIDs.contains($0.projectID) }

        // Stop is terminal, even when a stale device has edited the session's metadata.
        let localSessions = Dictionary(uniqueKeysWithValues: local.sessions.map { ($0.id, $0) })
        let remoteSessions = Dictionary(uniqueKeysWithValues: remote.snapshot.sessions.map { ($0.id, $0) })
        for index in sessions.indices where sessions[index].endedAt == nil {
            if let stopped = [localSessions[sessions[index].id], remoteSessions[sessions[index].id]]
                .compactMap({ $0 }).first(where: { $0.endedAt != nil }) {
                sessions[index].endedAt = stopped.endedAt
                sessions[index].pausedAt = nil
                sessions[index].accumulatedPausedDuration = stopped.accumulatedPausedDuration
            }
        }

        // Concurrent offline starts retain both records, but only the latest start runs.
        let active = sessions.filter(\.isActive).sorted {
            if $0.referenceDate == $1.referenceDate { return $0.id.uuidString > $1.id.uuidString }
            return $0.referenceDate > $1.referenceDate
        }
        if let winner = active.first {
            for index in sessions.indices where sessions[index].isActive && sessions[index].id != winner.id {
                sessions[index].endedAt = max(sessions[index].startedAt ?? winner.referenceDate,
                                             sessions[index].pausedAt ?? winner.referenceDate)
                sessions[index].pausedAt = nil
            }
        }
        result.snapshot = TickWidgetStorageSnapshot(
            projects: projects.sorted { $0.id.uuidString < $1.id.uuidString },
            sessions: sessions.sorted { $0.id.uuidString < $1.id.uuidString },
            autoTickRules: merge(base.autoTickRules, local.autoTickRules, remote.snapshot.autoTickRules)
                .filter { !result.deletedRules.contains($0.id) && projectIDs.contains($0.projectID) }
                .sorted { $0.id.uuidString < $1.id.uuidString }
        )
        return result
    }

    private static func merge<T: Identifiable & Equatable>(
        _ base: [T], _ local: [T], _ remote: [T]
    ) -> [T] where T.ID == UUID {
        let previous = Dictionary(uniqueKeysWithValues: base.map { ($0.id, $0) })
        var merged = Dictionary(uniqueKeysWithValues: remote.map { ($0.id, $0) })
        for value in local where previous[value.id] != value {
            merged[value.id] = value
        }
        return Array(merged.values)
    }
}

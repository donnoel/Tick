import Foundation

nonisolated struct TickWidgetSnapshot: Codable, Equatable {
    var hasProjects: Bool
    var defaultProjectID: UUID?
    var defaultProjectName: String?
    var activeSessionID: UUID?
    var activeProjectName: String?
    var activeSessionTitle: String?
    var activeStartedAt: Date?
    var activePausedAt: Date? = nil
    var activeElapsedDuration: TimeInterval? = nil
    var todayTotalDuration: TimeInterval
    var lastUpdatedAt: Date

    var isActivePaused: Bool {
        activeSessionID != nil && activePausedAt != nil
    }

    static func empty(lastUpdatedAt: Date = .now) -> TickWidgetSnapshot {
        TickWidgetSnapshot(
            hasProjects: false,
            defaultProjectID: nil,
            defaultProjectName: nil,
            activeSessionID: nil,
            activeProjectName: nil,
            activeSessionTitle: nil,
            activeStartedAt: nil,
            activePausedAt: nil,
            activeElapsedDuration: nil,
            todayTotalDuration: 0,
            lastUpdatedAt: lastUpdatedAt
        )
    }
}

nonisolated enum TickWidgetSnapshotBuilder {
    static func snapshot(
        from storageSnapshot: TickWidgetStorageSnapshot,
        defaultProjectID: UUID?,
        at date: Date = .now,
        calendar: Calendar = .current
    ) -> TickWidgetSnapshot {
        let activeProjects = TickWidgetStoredProject.activeSortedByDisplayOrder(storageSnapshot.projects)
        let verifiedDefaultProject = activeProjects.first { $0.id == defaultProjectID } ?? activeProjects.first
        let activeSession = storageSnapshot.sessions.first { $0.isActive }
        let activeProject = activeSession.flatMap { session in
            storageSnapshot.projects.first { $0.id == session.projectID }
        }
        let activeElapsedDuration = activeSession.map { $0.duration(at: date) }

        return TickWidgetSnapshot(
            hasProjects: !activeProjects.isEmpty,
            defaultProjectID: verifiedDefaultProject?.id,
            defaultProjectName: verifiedDefaultProject?.name,
            activeSessionID: activeSession?.id,
            activeProjectName: activeProject?.name,
            activeSessionTitle: activeSession.flatMap { displayTitle(for: $0, sessions: storageSnapshot.sessions, calendar: calendar) },
            activeStartedAt: activeSession?.startedAt,
            activePausedAt: activeSession?.pausedAt,
            activeElapsedDuration: activeElapsedDuration,
            todayTotalDuration: totalDurationToday(for: storageSnapshot.sessions, at: date, calendar: calendar),
            lastUpdatedAt: date
        )
    }

    private static func displayTitle(
        for session: TickWidgetStoredSession,
        sessions: [TickWidgetStoredSession],
        calendar: Calendar
    ) -> String? {
        let trimmedTitle = session.title.trimmingCharacters(in: .whitespacesAndNewlines)

        guard trimmedTitle.isEmpty else {
            return trimmedTitle
        }

        let fallbackTitles = Dictionary(
            uniqueKeysWithValues: sessions
                .filter { calendar.isDate($0.referenceDate, inSameDayAs: session.referenceDate) }
                .sorted { $0.referenceDate > $1.referenceDate }
                .filter { $0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                .enumerated()
                .map { index, session in
                    (session.id, "\(index + 1) Tick")
                }
        )

        return fallbackTitles[session.id] ?? "Tick"
    }

    private static func totalDurationToday(
        for sessions: [TickWidgetStoredSession],
        at date: Date,
        calendar: Calendar
    ) -> TimeInterval {
        sessions.reduce(0) { total, session in
            guard calendar.isDate(session.referenceDate, inSameDayAs: date) else {
                return total
            }

            return total + session.duration(at: date)
        }
    }
}

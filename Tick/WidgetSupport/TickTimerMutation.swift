import Foundation

nonisolated public enum TickTimerMutation {
    public enum Failure: LocalizedError, Equatable {
        case alreadyActive
        case unavailableSpace
        case changedSession

        public var errorDescription: String? {
            switch self {
            case .alreadyActive: "Stop the current Tick before starting another one."
            case .unavailableSpace: "This Space is no longer available. Choose another Space."
            case .changedSession: "The active Tick changed. Review it before stopping."
            }
        }
    }

    public static func start(in snapshot: inout TickWidgetStorageSnapshot, projectID: UUID,
                             sessionID: UUID = UUID(), at date: Date) throws {
        guard !snapshot.sessions.contains(where: \.isActive) else { throw Failure.alreadyActive }
        guard snapshot.projects.contains(where: { $0.id == projectID && !$0.isArchived }) else {
            throw Failure.unavailableSpace
        }
        snapshot.sessions.insert(TickWidgetStoredSession(
            id: sessionID, projectID: projectID, title: "", notes: "", startedAt: date,
            endedAt: nil, manualDuration: nil, entrySource: "timer", autoTickRuleID: nil,
            createdAt: date
        ), at: 0)
    }

    /// Stop the session the user saw, never a different timer started during refresh.
    /// Repeated Stop is harmless; stopping a paused Tick excludes its paused time.
    public static func stop(in snapshot: inout TickWidgetStorageSnapshot, sessionID: UUID,
                            at date: Date) throws {
        guard let index = snapshot.sessions.firstIndex(where: { $0.id == sessionID }) else {
            throw Failure.changedSession
        }
        guard snapshot.sessions[index].isActive else { return }
        snapshot.sessions[index].endedAt = stopDate(startedAt: snapshot.sessions[index].startedAt,
                                                  pausedAt: snapshot.sessions[index].pausedAt, at: date)
        snapshot.sessions[index].pausedAt = nil
        snapshot.sessions.sort { $0.referenceDate > $1.referenceDate }
    }

    public static func stopDate(startedAt: Date?, pausedAt: Date?, at date: Date) -> Date {
        max(startedAt ?? date, pausedAt ?? date)
    }
}

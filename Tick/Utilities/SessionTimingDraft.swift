import Foundation

/// An unsaved timing edit. The original timing also guards against stale edits.
nonisolated struct SessionTimingDraft {
    private let original: TimeSession
    private let originalDuration: TimeInterval
    var startedAt: Date
    var duration: TimeInterval
    var source: SessionEntrySource

    init(session: TimeSession, at date: Date = .now) {
        original = session
        originalDuration = session.duration(at: date)
        startedAt = session.referenceDate
        duration = originalDuration
        source = session.entrySource
    }

    var hasChanges: Bool {
        startedAt != original.referenceDate || duration != originalDuration || source != original.entrySource
    }

    var pausedDuration: TimeInterval {
        source == .manual || original.entrySource == .manual ? 0 : max(0, original.accumulatedPausedDuration ?? 0)
    }

    var endedAt: Date {
        get { startedAt.addingTimeInterval(duration + pausedDuration) }
        set { duration = newValue.timeIntervalSince(startedAt) - pausedDuration }
    }

    var validationMessage: String? {
        guard startedAt.timeIntervalSinceReferenceDate.isFinite,
              duration.isFinite, endedAt.timeIntervalSinceReferenceDate.isFinite else {
            return "Enter a valid start and duration."
        }
        guard duration > 0 else {
            return "Duration must be greater than zero. End must be after Start and any recorded pauses."
        }
        return nil
    }

    func applying(to session: TimeSession) throws -> TimeSession {
        guard !session.isActive else {
            throw TimingError.invalid("Stop this Tick before editing its timing.")
        }
        guard session.startedAt == original.startedAt, session.endedAt == original.endedAt,
              session.manualDuration == original.manualDuration, session.pausedAt == original.pausedAt,
              session.accumulatedPausedDuration == original.accumulatedPausedDuration,
              session.entrySource == original.entrySource, session.autoTickRuleID == original.autoTickRuleID else {
            throw TimingError.invalid("This Tick's timing changed while you were editing. Reopen it to review the latest timing.")
        }
        if let validationMessage { throw TimingError.invalid(validationMessage) }

        var updated = session
        updated.startedAt = startedAt
        updated.entrySource = source
        updated.pausedAt = nil
        if source == .manual {
            updated.manualDuration = duration
            updated.endedAt = nil
            updated.accumulatedPausedDuration = nil
        } else {
            updated.manualDuration = nil
            updated.endedAt = endedAt // Source changes always produce a completed Tick.
            updated.accumulatedPausedDuration = pausedDuration > 0 ? pausedDuration : nil
        }
        if source != .autoLocation { updated.autoTickRuleID = nil }
        return updated
    }

    private enum TimingError: LocalizedError {
        case invalid(String)
        var errorDescription: String? {
            switch self { case .invalid(let message): message }
        }
    }
}

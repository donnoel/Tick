import Foundation

nonisolated enum SessionFallbackTitleProvider {
    static func untitledSessionTitles(for sessions: [TimeSession]) -> [TimeSession.ID: String] {
        Dictionary(
            uniqueKeysWithValues: sessions
                .filter { $0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                .enumerated()
                .map { index, session in
                    (session.id, "\(index + 1) Tick")
                }
        )
    }

    static func fallbackTitle(for session: TimeSession, in sessions: [TimeSession]) -> String {
        untitledSessionTitles(for: sessions)[session.id] ?? "Tick"
    }
}

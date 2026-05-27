import Foundation

nonisolated enum SummaryPeriod: String, CaseIterable, Identifiable {
    case day
    case week
    case month

    var id: String { rawValue }

    var title: String {
        switch self {
        case .day:
            "Daily"
        case .week:
            "Weekly"
        case .month:
            "Monthly"
        }
    }

    func interval(containing date: Date, calendar: Calendar = .current) -> DateInterval {
        switch self {
        case .day:
            calendar.dateInterval(of: .day, for: date) ?? DateInterval(start: date, duration: 0)
        case .week:
            calendar.dateInterval(of: .weekOfYear, for: date) ?? DateInterval(start: date, duration: 0)
        case .month:
            calendar.dateInterval(of: .month, for: date) ?? DateInterval(start: date, duration: 0)
        }
    }
}

nonisolated struct ProjectDurationSummary: Equatable, Identifiable {
    let projectID: TickProject.ID
    let projectName: String
    let duration: TimeInterval

    var id: TickProject.ID { projectID }
}

nonisolated struct TickSummary: Equatable {
    let period: SummaryPeriod
    let totalDuration: TimeInterval
    let durationByProject: [ProjectDurationSummary]
    let sessionCount: Int
}

nonisolated enum TickSummaryCalculator {
    static func summary(
        for period: SummaryPeriod,
        projects: [TickProject],
        sessions: [TimeSession],
        referenceDate: Date = .now,
        calendar: Calendar = .current
    ) -> TickSummary {
        let interval = period.interval(containing: referenceDate, calendar: calendar)
        let projectNamesByID = Dictionary(uniqueKeysWithValues: projects.map { ($0.id, $0.name) })
        let periodSessions = sessions.filter { interval.contains($0.referenceDate) }
        let durationsByProject = Dictionary(grouping: periodSessions, by: \.projectID)
            .map { projectID, sessions in
                ProjectDurationSummary(
                    projectID: projectID,
                    projectName: projectNamesByID[projectID] ?? "Unknown Space",
                    duration: sessions.reduce(0) { $0 + $1.duration(at: referenceDate) }
                )
            }
            .sorted { lhs, rhs in
                if lhs.duration == rhs.duration {
                    return lhs.projectName.localizedCaseInsensitiveCompare(rhs.projectName) == .orderedAscending
                }

                return lhs.duration > rhs.duration
            }

        let totalDuration = periodSessions.reduce(0) { $0 + $1.duration(at: referenceDate) }

        return TickSummary(
            period: period,
            totalDuration: totalDuration,
            durationByProject: durationsByProject,
            sessionCount: periodSessions.count
        )
    }
}

import Foundation

nonisolated enum SummaryPeriod: String, CaseIterable, Identifiable {
    case day
    case week
    case month
    case year
    case lifetime

    var id: String { rawValue }

    var title: String {
        switch self {
        case .day:
            "Daily"
        case .week:
            "Weekly"
        case .month:
            "Monthly"
        case .year:
            "Year"
        case .lifetime:
            "Lifetime"
        }
    }

    var pickerTitle: String {
        switch self {
        case .day:
            "Day"
        case .week:
            "Week"
        case .month:
            "Month"
        case .year:
            "Year"
        case .lifetime:
            "All"
        }
    }

    var timelineTitle: String? {
        switch self {
        case .day:
            nil
        case .week, .month:
            "Time by Day"
        case .year:
            "Time by Month"
        case .lifetime:
            "Time by Year"
        }
    }

    var timelineComponent: Calendar.Component {
        switch self {
        case .day, .week, .month:
            .day
        case .year:
            .month
        case .lifetime:
            .year
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
        case .year:
            calendar.dateInterval(of: .year, for: date) ?? DateInterval(start: date, duration: 0)
        case .lifetime:
            DateInterval(start: .distantPast, end: .distantFuture)
        }
    }

    func timelineBucketStart(for date: Date, calendar: Calendar = .current) -> Date? {
        switch self {
        case .day:
            nil
        case .week, .month:
            calendar.startOfDay(for: date)
        case .year:
            calendar.dateInterval(of: .month, for: date)?.start
        case .lifetime:
            calendar.dateInterval(of: .year, for: date)?.start
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

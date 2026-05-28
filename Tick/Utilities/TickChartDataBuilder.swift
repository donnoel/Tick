import Foundation

nonisolated struct TickProjectChartEntry: Equatable, Identifiable {
    let projectID: TickProject.ID
    let projectName: String
    let duration: TimeInterval

    var id: TickProject.ID { projectID }
    var hours: Double { duration / 3_600 }
}

nonisolated struct TickDayChartEntry: Equatable, Identifiable {
    let date: Date
    let duration: TimeInterval

    var id: Date { date }
    var hours: Double { duration / 3_600 }
}

nonisolated struct TickDayProjectChartEntry: Equatable, Identifiable {
    let date: Date
    let projectID: TickProject.ID
    let projectName: String
    let duration: TimeInterval

    var id: String { "\(date.timeIntervalSince1970)-\(projectID.uuidString)" }
    var hours: Double { duration / 3_600 }
}

nonisolated enum TickChartDataBuilder {
    static func projectEntries(
        for period: SummaryPeriod,
        projects: [TickProject],
        sessions: [TimeSession],
        referenceDate: Date,
        calendar: Calendar = .current
    ) -> [TickProjectChartEntry] {
        let interval = period.interval(containing: referenceDate, calendar: calendar)
        let projectByID = Dictionary(uniqueKeysWithValues: projects.map { ($0.id, $0) })

        return Dictionary(grouping: sessions.filter { interval.contains($0.referenceDate) }, by: \.projectID)
            .compactMap { projectID, groupedSessions in
                guard let project = projectByID[projectID] else {
                    return nil
                }

                let duration = groupedSessions.reduce(0) { total, session in
                    total + session.duration(at: referenceDate)
                }

                guard duration > 0 else {
                    return nil
                }

                return TickProjectChartEntry(
                    projectID: projectID,
                    projectName: project.name,
                    duration: duration
                )
            }
            .sorted { lhs, rhs in
                if lhs.duration == rhs.duration {
                    return lhs.projectName.localizedCaseInsensitiveCompare(rhs.projectName) == .orderedAscending
                }

                return lhs.duration > rhs.duration
            }
    }

    static func dayEntries(
        for period: SummaryPeriod,
        sessions: [TimeSession],
        referenceDate: Date,
        calendar: Calendar = .current
    ) -> [TickDayChartEntry] {
        switch period {
        case .day:
            return []
        case .week, .month:
            let interval = period.interval(containing: referenceDate, calendar: calendar)
            let startOfFirstDay = calendar.startOfDay(for: interval.start)

            let totalDays = calendar.dateComponents([.day], from: startOfFirstDay, to: interval.end).day ?? 0
            guard totalDays > 0 else {
                return []
            }

            let periodSessions = sessions.filter { interval.contains($0.referenceDate) }
            let durationsByDay = Dictionary(grouping: periodSessions) { session in
                calendar.startOfDay(for: session.referenceDate)
            }

            return (0..<totalDays).compactMap { offset in
                guard let day = calendar.date(byAdding: .day, value: offset, to: startOfFirstDay) else {
                    return nil
                }

                let duration = (durationsByDay[day] ?? []).reduce(0) { total, session in
                    total + session.duration(at: referenceDate)
                }

                return TickDayChartEntry(date: day, duration: duration)
            }
        }
    }

    static func dayProjectEntries(
        for period: SummaryPeriod,
        projects: [TickProject],
        sessions: [TimeSession],
        referenceDate: Date,
        calendar: Calendar = .current
    ) -> [TickDayProjectChartEntry] {
        switch period {
        case .day:
            return []
        case .week, .month:
            let interval = period.interval(containing: referenceDate, calendar: calendar)
            let projectByID = Dictionary(uniqueKeysWithValues: projects.map { ($0.id, $0) })
            let periodSessions = sessions.filter { interval.contains($0.referenceDate) }

            return Dictionary(grouping: periodSessions) { session in
                DayProjectKey(
                    date: calendar.startOfDay(for: session.referenceDate),
                    projectID: session.projectID
                )
            }
            .compactMap { key, groupedSessions in
                guard let project = projectByID[key.projectID] else {
                    return nil
                }

                let duration = groupedSessions.reduce(0) { total, session in
                    total + session.duration(at: referenceDate)
                }

                guard duration > 0 else {
                    return nil
                }

                return TickDayProjectChartEntry(
                    date: key.date,
                    projectID: key.projectID,
                    projectName: project.name,
                    duration: duration
                )
            }
            .sorted { lhs, rhs in
                if lhs.date != rhs.date {
                    return lhs.date < rhs.date
                }

                return lhs.projectName.localizedCaseInsensitiveCompare(rhs.projectName) == .orderedAscending
            }
        }
    }
}

nonisolated private struct DayProjectKey: Hashable {
    let date: Date
    let projectID: TickProject.ID
}

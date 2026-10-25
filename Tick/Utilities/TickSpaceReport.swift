import Foundation

nonisolated struct TickReportDateRange: Equatable {
    let start: Date
    let end: Date
    let endExclusive: Date

    init(start: Date, end: Date, calendar: Calendar = .current) {
        self.start = calendar.startOfDay(for: min(start, end))
        self.end = calendar.startOfDay(for: max(start, end))
        self.endExclusive = calendar.date(byAdding: .day, value: 1, to: self.end) ?? self.end
    }

    static func initial(
        period: SummaryPeriod,
        projectID: TickProject.ID,
        sessions: [TimeSession],
        referenceDate: Date,
        calendar: Calendar = .current
    ) -> Self {
        if period == .lifetime {
            let dates = sessions.filter { $0.projectID == projectID }.map(\.referenceDate)
            return Self(start: dates.min() ?? referenceDate, end: dates.max() ?? referenceDate, calendar: calendar)
        }

        let interval = period.interval(containing: referenceDate, calendar: calendar)
        let lastDay = calendar.date(byAdding: .day, value: -1, to: interval.end) ?? interval.start
        return Self(start: interval.start, end: lastDay, calendar: calendar)
    }

    func contains(_ date: Date) -> Bool {
        date >= start && date < endExclusive
    }

    var title: String {
        let first = start.formatted(date: .abbreviated, time: .omitted)
        guard start != end else { return first }
        return "\(first) – \(end.formatted(date: .abbreviated, time: .omitted))"
    }
}

/// A read-only snapshot: screen totals and shared text use the same durations.
nonisolated struct TickSpaceReport {
    struct Description: Hashable {
        let title: String
        let notes: String
    }

    struct Entry: Identifiable {
        let id: TimeSession.ID
        let date: Date
        let description: Description
        let duration: TimeInterval
        let status: String
    }

    struct Work: Identifiable {
        let id: Description
        let duration: TimeInterval
        let sessionCount: Int
    }

    struct Day: Identifiable {
        let id: Date
        let entries: [Entry]
        var duration: TimeInterval { entries.reduce(0) { $0 + $1.duration } }
    }

    let projectName: String
    let range: TickReportDateRange
    let generatedAt: Date
    let entries: [Entry]
    let work: [Work]
    let days: [Day]
    let activeSessionCount: Int

    var totalDuration: TimeInterval { entries.reduce(0) { $0 + $1.duration } }
    var sessionCount: Int { entries.count }
    var subject: String { "\(projectName) — Work report — \(range.title)" }

    init(
        projectID: TickProject.ID,
        projectName: String,
        range: TickReportDateRange,
        sessions: [TimeSession],
        generatedAt: Date = .now,
        includeNotes: Bool = true,
        calendar: Calendar = .current
    ) {
        self.projectName = projectName
        self.range = range
        self.generatedAt = generatedAt
        let matchingSessions = sessions.filter { $0.projectID == projectID && range.contains($0.referenceDate) }
        activeSessionCount = matchingSessions.filter(\.isActive).count
        let entries = matchingSessions.map { session in
            let title = session.title.trimmingCharacters(in: .whitespacesAndNewlines)
            let notes = includeNotes ? session.notes.trimmingCharacters(in: .whitespacesAndNewlines) : ""
            let status: String
            if session.isPaused {
                status = "Paused"
            } else if session.isActive {
                status = "Running"
            } else {
                switch session.entrySource {
                case .timer: status = "Timer"
                case .manual: status = "Manual"
                case .autoLocation: status = "Auto Tick"
                }
            }
            return Entry(
                id: session.id,
                date: session.referenceDate,
                description: Description(title: title.isEmpty ? "Untitled work" : title, notes: notes),
                duration: session.duration(at: generatedAt),
                status: status
            )
        }.sorted {
            if $0.date == $1.date { return $0.id.uuidString < $1.id.uuidString }
            return $0.date < $1.date
        }
        self.entries = entries
        work = Dictionary(grouping: entries, by: \.description).map { description, entries in
            Work(id: description, duration: entries.reduce(0) { $0 + $1.duration }, sessionCount: entries.count)
        }.sorted {
            if $0.duration != $1.duration { return $0.duration > $1.duration }
            if $0.id.title != $1.id.title { return $0.id.title < $1.id.title }
            return $0.id.notes < $1.id.notes
        }
        days = Dictionary(grouping: entries, by: { calendar.startOfDay(for: $0.date) })
            .map { Day(id: $0.key, entries: $0.value) }
            .sorted { $0.id < $1.id }
    }

    var sharedText: String {
        // Paragraphs survive sharing to both Mail and Messages without relying on
        // Markdown, fixed-width columns, or rich-text support in the receiving app.
        var sections = [
            "\(projectName)\nWork report\n\n\(range.title)",
            "Overview\n\nTotal time: \(Self.durationText(totalDuration))\n\(sessionCount) \(sessionCount == 1 ? "session" : "sessions") across \(days.count) \(days.count == 1 ? "day" : "days")"
        ]
        if activeSessionCount > 0 {
            sections[1] += "\n\nIncludes \(activeSessionCount) running or paused \(activeSessionCount == 1 ? "session" : "sessions").\nTime captured as of \(generatedAt.formatted(.dateTime.year().month().day().hour().minute().timeZone()))."
        }
        guard !work.isEmpty else {
            sections.append("No time recorded in this period.")
            return sections.joined(separator: "\n\n\n")
        }

        let workBlocks = work.enumerated().map { index, item in
            var block = "\(index + 1). \(item.id.title)\nTime: \(Self.durationText(item.duration))"
            if item.sessionCount > 1 { block += " across \(item.sessionCount) sessions" }
            if !item.id.notes.isEmpty { block += "\nNotes: \(item.id.notes)" }
            return block
        }
        sections.append("Work summary\n\n" + workBlocks.joined(separator: "\n\n"))

        var dayBlocks: [String] = []
        for day in days {
            let heading = "\(day.id.formatted(date: .complete, time: .omitted))\nDaily total: \(Self.durationText(day.duration))"
            let entryBlocks = day.entries.map { entry in
                // Manual entries have a recorded date, not a claimed start/end time.
                let timing = entry.status == "Manual" ? "Recorded manually" : "Started: \(entry.date.formatted(date: .omitted, time: .shortened)) · \(entry.status)"
                var block = "• \(entry.description.title)\nTime: \(Self.durationText(entry.duration))\n\(timing)"
                if !entry.description.notes.isEmpty { block += "\nNotes: \(entry.description.notes)" }
                return block
            }
            dayBlocks.append(heading + "\n\n" + entryBlocks.joined(separator: "\n\n"))
        }
        sections.append("Daily detail\n\n" + dayBlocks.joined(separator: "\n\n\n"))
        return sections.joined(separator: "\n\n\n")
    }

    static func durationText(_ duration: TimeInterval) -> String {
        let seconds = max(0, Int(duration.rounded(.down)))
        let hours = seconds / 3_600
        let minutes = (seconds % 3_600) / 60
        let remainder = seconds % 60
        var parts: [String] = []
        if hours > 0 { parts.append("\(hours)h") }
        if minutes > 0 { parts.append("\(minutes)m") }
        if remainder > 0 || parts.isEmpty { parts.append("\(remainder)s") }
        return parts.joined(separator: " ")
    }
}

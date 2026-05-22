import Foundation

nonisolated struct TickAccessoryWidgetContent: Equatable {
    enum State: Equatable {
        case noProjects
        case idle
        case active
    }

    var state: State
    var rectangularTitle: String
    var rectangularDetail: String
    var rectangularFootnote: String?
    var circularText: String
    var circularSystemImage: String?
    var inlineText: String
    var accessibilityLabel: String
}

nonisolated enum TickAccessoryWidgetContentBuilder {
    static func content(from snapshot: TickWidgetSnapshot, at date: Date = .now) -> TickAccessoryWidgetContent {
        guard snapshot.hasProjects else {
            return TickAccessoryWidgetContent(
                state: .noProjects,
                rectangularTitle: "Ticks",
                rectangularDetail: "Create a project",
                rectangularFootnote: nil,
                circularText: "0",
                circularSystemImage: "timer",
                inlineText: "Ticks: create a project",
                accessibilityLabel: "Ticks. Create a project to start tracking."
            )
        }

        guard snapshot.activeSessionID != nil else {
            let total = compactDurationString(from: snapshot.todayTotalDuration)
            let projectName = snapshot.defaultProjectName

            return TickAccessoryWidgetContent(
                state: .idle,
                rectangularTitle: "Ticks",
                rectangularDetail: total,
                rectangularFootnote: projectName,
                circularText: total,
                circularSystemImage: "timer",
                inlineText: "Ticks: \(total) today",
                accessibilityLabel: accessibilityParts(["Ticks idle", "\(total) today", projectName]).joined(separator: ". ")
            )
        }

        let elapsed = compactDurationString(from: elapsedDuration(from: snapshot.activeStartedAt, at: date))
        let projectName = snapshot.activeProjectName ?? "Ticks"

        return TickAccessoryWidgetContent(
            state: .active,
            rectangularTitle: projectName,
            rectangularDetail: elapsed,
            rectangularFootnote: "Running",
            circularText: elapsed,
            circularSystemImage: elapsed.count > 4 ? "timer" : nil,
            inlineText: "\(projectName) running \(elapsed)",
            accessibilityLabel: "\(projectName) running. Elapsed time \(elapsed)."
        )
    }

    static func compactDurationString(from duration: TimeInterval) -> String {
        let totalMinutes = max(0, Int(duration.rounded(.down)) / 60)
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }

        return "\(minutes)m"
    }

    private static func elapsedDuration(from startDate: Date?, at date: Date) -> TimeInterval {
        guard let startDate else {
            return 0
        }

        return max(0, date.timeIntervalSince(startDate))
    }

    private static func accessibilityParts(_ parts: [String?]) -> [String] {
        parts.compactMap { value in
            let trimmedValue = value?.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmedValue?.isEmpty == false ? trimmedValue : nil
        }
    }
}

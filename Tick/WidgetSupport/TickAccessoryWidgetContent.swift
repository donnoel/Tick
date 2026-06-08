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
                rectangularDetail: "Create a space",
                rectangularFootnote: nil,
                circularText: "0",
                circularSystemImage: "timer",
                inlineText: "Ticks: create a space",
                accessibilityLabel: "Ticks. Create a space to start ticking."
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

        let total = compactDurationString(from: snapshot.todayTotalDuration)
        let projectName = snapshot.activeProjectName ?? "Ticks"
        let status = snapshot.isActivePaused ? "Paused" : "Running"
        let spokenStatus = snapshot.isActivePaused ? "paused" : "running"

        return TickAccessoryWidgetContent(
            state: .active,
            rectangularTitle: projectName,
            rectangularDetail: total,
            rectangularFootnote: status,
            circularText: total,
            circularSystemImage: total.count > 4 ? "timer" : nil,
            inlineText: "\(projectName): \(total) today",
            accessibilityLabel: "\(projectName) \(spokenStatus). \(total) today."
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

    private static func accessibilityParts(_ parts: [String?]) -> [String] {
        parts.compactMap { value in
            let trimmedValue = value?.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmedValue?.isEmpty == false ? trimmedValue : nil
        }
    }
}

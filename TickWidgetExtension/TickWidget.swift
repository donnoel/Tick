import AppIntents
import SwiftUI
import WidgetKit

struct TickWidgetEntry: TimelineEntry {
    let date: Date
    let snapshot: TickWidgetSnapshot
}

struct TickWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> TickWidgetEntry {
        TickWidgetEntry(
            date: .now,
            snapshot: TickWidgetSnapshot.empty()
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (TickWidgetEntry) -> Void) {
        completion(TickWidgetEntry(date: .now, snapshot: loadSnapshot()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TickWidgetEntry>) -> Void) {
        let date = Date()
        let entry = TickWidgetEntry(date: date, snapshot: loadSnapshot(at: date))
        let nextRefresh = Calendar.current.date(byAdding: .minute, value: 15, to: date) ?? date.addingTimeInterval(900)
        completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
    }

    private func loadSnapshot(at date: Date = .now) -> TickWidgetSnapshot {
        do {
            return try TickWidgetActionStore().loadWidgetSnapshot(at: date)
        } catch {
            return .empty(lastUpdatedAt: date)
        }
    }
}

struct TickWidgetView: View {
    @Environment(\.widgetFamily) private var family
    @Environment(\.colorScheme) private var colorScheme
    let entry: TickWidgetEntry

    var body: some View {
        Group {
            switch family {
            case .accessoryRectangular:
                accessoryRectangularView
            case .accessoryCircular:
                accessoryCircularView
            case .accessoryInline:
                accessoryInlineView
            default:
                homeScreenView
            }
        }
        .containerBackground(for: .widget) {
            widgetBackground
        }
        .widgetURL(URL(string: "tick://today"))
    }

    private var homeScreenView: some View {
        VStack(alignment: .leading, spacing: 10) {
            switch state {
            case .noProjects:
                noProjectsView
            case .idle:
                idleView
            case .active:
                activeView
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var widgetBackground: some View {
        LinearGradient(
            colors: [
                TickWidgetStyle.backgroundTop(for: colorScheme),
                TickWidgetStyle.backgroundBottom(for: colorScheme)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var state: TickWidgetState {
        if !entry.snapshot.hasProjects {
            return .noProjects
        }

        if entry.snapshot.activeSessionID != nil {
            return .active
        }

        return .idle
    }

    private var accessoryContent: TickAccessoryWidgetContent {
        TickAccessoryWidgetContentBuilder.content(from: entry.snapshot, at: entry.date)
    }

    private var noProjectsView: some View {
        VStack(alignment: .leading, spacing: 10) {
            widgetHeader(title: "Ticks", systemImage: "timer")

            Text("Create a space to start recording.")
                .font(.headline)
                .foregroundStyle(.secondary)
                .lineLimit(3)
                .minimumScaleFactor(0.82)

            Spacer(minLength: 0)

            Label("Open Tick", systemImage: "chevron.forward")
                .font(.caption.weight(.semibold))
                .foregroundStyle(TickWidgetStyle.primary)
        }
        .accessibilityElement(children: .combine)
    }

    private var idleView: some View {
        VStack(alignment: .leading, spacing: 8) {
            widgetHeader(title: "Ticks", systemImage: "timer")

            Text(shortDurationString(from: entry.snapshot.todayTotalDuration))
                .font(.system(size: family == .systemSmall ? 36 : 44, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.72)

            if let projectName = entry.snapshot.defaultProjectName {
                widgetDetailRow(systemImage: "folder.fill", text: projectName)
            }

            TickWidgetProgressBar(progress: todayProgress)
                .accessibilityHidden(true)

            Spacer(minLength: 0)

            actionFooter(title: "Start Tick", caption: "Ready", systemImage: "play.fill", tint: TickWidgetStyle.primary, intent: StartTickIntent())
        }
    }

    private var activeView: some View {
        let isSmall = family == .systemSmall

        return VStack(alignment: .leading, spacing: isSmall ? 6 : 8) {
            widgetHeader(
                title: entry.snapshot.isActivePaused ? "Paused" : "Running",
                systemImage: entry.snapshot.isActivePaused ? "pause.circle.fill" : "record.circle.fill",
                tint: TickWidgetStyle.running,
                showsToday: !isSmall
            )

            Text(entry.snapshot.activeProjectName ?? "Ticks")
                .font((isSmall ? Font.subheadline : Font.headline).weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            if !isSmall {
                Text(entry.snapshot.activeSessionTitle ?? "Tick")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            if entry.snapshot.isActivePaused, let activeElapsedDuration = entry.snapshot.activeElapsedDuration {
                Text(timerDurationString(from: activeElapsedDuration))
                    .font(.system(size: isSmall ? 30 : 40, weight: .bold, design: .rounded).monospacedDigit())
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                    .accessibilityLabel("Paused elapsed time")
            } else if let runningTimerStartDate = entry.snapshot.runningTimerStartDate {
                Text(runningTimerStartDate, style: .timer)
                    .font(.system(size: isSmall ? 30 : 40, weight: .bold, design: .rounded).monospacedDigit())
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                    .accessibilityLabel("Elapsed time")
            } else {
                Text("Running")
                    .font(.title2.weight(.bold))
            }

            Spacer(minLength: 0)

            actionFooter(
                title: "Stop Tick",
                caption: entry.snapshot.isActivePaused ? "Paused" : "Running",
                systemImage: "stop.fill",
                tint: TickWidgetStyle.running,
                intent: StopTickIntent()
            )
        }
    }

    private var todayProgress: Double {
        let hours = entry.snapshot.todayTotalDuration / 3_600
        return min(max(hours / 8, 0), 1)
    }

    private func widgetHeader(
        title: String,
        systemImage: String,
        tint: Color = TickWidgetStyle.primary,
        showsToday: Bool = true
    ) -> some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.caption.weight(.bold))
                .foregroundStyle(tint)
                .accessibilityHidden(true)

            Text(title)
                .font(.headline.weight(.semibold))
                .lineLimit(1)

            Spacer(minLength: 4)

            if showsToday {
                Text("Today")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func widgetDetailRow(systemImage: String, text: String) -> some View {
        Label {
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(family == .systemSmall ? 1 : 2)
                .minimumScaleFactor(0.82)
        } icon: {
            Image(systemName: systemImage)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(TickWidgetStyle.primary)
        }
    }

    private func actionFooter<I: AppIntent>(
        title: String,
        caption: String,
        systemImage: String,
        tint: Color,
        intent: I
    ) -> some View {
        let buttonSize: CGFloat = family == .systemSmall ? 34 : 38

        return HStack(spacing: 10) {
            HStack(spacing: 4) {
                Circle()
                    .fill(tint)
                    .frame(width: 5, height: 5)

                Text(caption)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .accessibilityHidden(true)

            Spacer(minLength: 4)

            Button(intent: intent) {
                Image(systemName: systemImage)
                    .font(.subheadline.weight(.bold))
                    .frame(width: buttonSize, height: buttonSize)
                    .background(tint, in: Circle())
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(title)
            .accessibilityHint(actionHint(for: title))
        }
        .padding(.top, 2)
    }

    private func actionHint(for title: String) -> String {
        switch title {
        case "Start Tick":
            return "Starts a Tick for the default space."
        case "Stop Tick":
            return "Stops the active Tick session."
        default:
            return title
        }
    }

    private var accessoryRectangularView: some View {
        HStack(alignment: .center, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(accessoryContent.rectangularTitle)
                    .font(.headline)
                    .lineLimit(1)

                Text(accessoryContent.rectangularDetail)
                    .font(.subheadline.monospacedDigit())
                    .lineLimit(1)

                if let footnote = accessoryContent.rectangularFootnote {
                    Text(footnote)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 4)

            accessoryActionButton
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessoryContent.accessibilityLabel)
    }

    @ViewBuilder
    private var accessoryActionButton: some View {
        switch accessoryContent.state {
        case .noProjects:
            Image(systemName: "chevron.forward")
                .font(.caption.weight(.semibold))
                .accessibilityHidden(true)
        case .idle:
            Button(intent: StartTickIntent()) {
                Image(systemName: "play.fill")
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Start Tick")
            .accessibilityHint("Starts a Tick for the default space.")
        case .active:
            Button(intent: StopTickIntent()) {
                Image(systemName: "stop.fill")
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Stop Tick")
            .accessibilityHint("Stops the active Tick session.")
        }
    }

    private var accessoryCircularView: some View {
        VStack(spacing: 2) {
            if let systemImage = accessoryContent.circularSystemImage {
                Image(systemName: systemImage)
                    .font(.caption)
                    .accessibilityHidden(true)
            }

            Text(accessoryContent.circularText)
                .font(.caption.monospacedDigit().weight(.semibold))
                .minimumScaleFactor(0.7)
                .lineLimit(1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessoryContent.accessibilityLabel)
    }

    private var accessoryInlineView: some View {
        Text(accessoryContent.inlineText)
            .accessibilityLabel(accessoryContent.accessibilityLabel)
    }

    private func shortDurationString(from duration: TimeInterval) -> String {
        TickAccessoryWidgetContentBuilder.compactDurationString(from: duration)
    }

    private func timerDurationString(from duration: TimeInterval) -> String {
        let totalSeconds = max(0, Int(duration.rounded(.down)))
        let hours = totalSeconds / 3_600
        let minutes = (totalSeconds % 3_600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }

        return String(format: "%02d:%02d", minutes, seconds)
    }
}

private enum TickWidgetState {
    case noProjects
    case idle
    case active
}

private enum TickWidgetStyle {
    static let primary = Color(red: 0.12, green: 0.45, blue: 0.94)
    static let running = Color(red: 0.48, green: 0.28, blue: 0.92)

    static func backgroundTop(for colorScheme: ColorScheme) -> Color {
        switch colorScheme {
        case .dark:
            Color(red: 0.10, green: 0.12, blue: 0.18)
        default:
            Color(red: 0.97, green: 0.99, blue: 1.0)
        }
    }

    static func backgroundBottom(for colorScheme: ColorScheme) -> Color {
        switch colorScheme {
        case .dark:
            Color(red: 0.16, green: 0.18, blue: 0.28)
        default:
            Color(red: 0.91, green: 0.94, blue: 1.0)
        }
    }
}

private struct TickWidgetProgressBar: View {
    let progress: Double

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.secondary.opacity(0.14))

                Capsule()
                    .fill(TickWidgetStyle.primary.opacity(0.82))
                    .frame(width: max(8, proxy.size.width * progress))
            }
        }
        .frame(height: 5)
    }
}

struct TickWidget: Widget {
    let kind = "TickWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TickWidgetProvider()) { entry in
            TickWidgetView(entry: entry)
        }
        .configurationDisplayName("Ticks")
        .description("Start or stop space recording.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryCircular, .accessoryInline])
    }
}

#Preview(as: .systemSmall) {
    TickWidget()
} timeline: {
    TickWidgetEntry(date: .now, snapshot: .empty())
}

#Preview(as: .accessoryRectangular) {
    TickWidget()
} timeline: {
    TickWidgetEntry(date: .now, snapshot: .empty())
}

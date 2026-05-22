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
    let entry: TickWidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
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
        .containerBackground(.background, for: .widget)
        .widgetURL(URL(string: "tick://today"))
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

    private var noProjectsView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Ticks")
                .font(.headline)

            Text("Create a project to start tracking.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }

    private var idleView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Ticks")
                .font(.headline)

            Text(shortDurationString(from: entry.snapshot.todayTotalDuration))
                .font(.title2.monospacedDigit().weight(.semibold))

            if let projectName = entry.snapshot.defaultProjectName {
                Text(projectName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(family == .systemSmall ? 1 : 2)
            }

            Spacer(minLength: 0)

            Button(intent: StartTickIntent()) {
                Label("Start", systemImage: "play.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .accessibilityHint("Starts a Tick for the default project.")
        }
    }

    private var activeView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(entry.snapshot.activeProjectName ?? "Ticks")
                .font(.headline)
                .lineLimit(family == .systemSmall ? 1 : 2)

            Text(entry.snapshot.activeSessionTitle ?? "Tick")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            if let activeStartedAt = entry.snapshot.activeStartedAt {
                Text(activeStartedAt, style: .timer)
                    .font(.title2.monospacedDigit().weight(.semibold))
                    .accessibilityLabel("Elapsed time")
            } else {
                Text("Running")
                    .font(.title2.weight(.semibold))
            }

            Spacer(minLength: 0)

            Button(intent: StopTickIntent()) {
                Label("Stop", systemImage: "stop.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .accessibilityHint("Stops the active Tick session.")
        }
    }

    private func shortDurationString(from duration: TimeInterval) -> String {
        let totalMinutes = max(0, Int(duration.rounded(.down)) / 60)
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }

        return "\(minutes)m"
    }
}

private enum TickWidgetState {
    case noProjects
    case idle
    case active
}

struct TickWidget: Widget {
    let kind = "TickWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TickWidgetProvider()) { entry in
            TickWidgetView(entry: entry)
        }
        .configurationDisplayName("Ticks")
        .description("Start or stop project time tracking.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

#Preview(as: .systemSmall) {
    TickWidget()
} timeline: {
    TickWidgetEntry(date: .now, snapshot: .empty())
}

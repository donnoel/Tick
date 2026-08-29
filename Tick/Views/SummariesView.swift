import Charts
import SwiftUI

struct SummariesView: View {
    let viewModel: TickViewModel
    @State private var selectedPeriod = SummaryPeriod.day

    var body: some View {
        NavigationStack {
            TimelineView(.periodic(from: .now, by: 60)) { timeline in
                let summary = viewModel.summary(for: selectedPeriod, at: timeline.date)
                let periodProjectChartEntries = TickChartDataBuilder.periodProjectEntries(
                    for: selectedPeriod,
                    projects: viewModel.projects,
                    sessions: viewModel.sessions,
                    referenceDate: timeline.date
                )
                let projectIDs = viewModel.projects.map(\.id)

                List {
                    Section {
                        Picker("Period", selection: $selectedPeriod) {
                            ForEach(SummaryPeriod.allCases) { period in
                                Text(period.pickerTitle)
                                    .accessibilityLabel(period.title)
                                    .tag(period)
                            }
                        }
                        .pickerStyle(.segmented)
                        .accessibilityHint("Choose a daily, weekly, monthly, yearly, or lifetime summary.")
                    }
                    .listRowBackground(Color.clear)

                    Section {
                        SummaryHeroCard(
                            periodTitle: selectedPeriod.title,
                            totalDuration: summary.totalDuration,
                            sessionCount: summary.sessionCount
                        )
                    }
                    .listRowBackground(Color.clear)

                    if let timelineTitle = selectedPeriod.timelineTitle {
                        Section {
                            if periodProjectChartEntries.isEmpty {
                                Text("No time recorded in this period.")
                                    .foregroundStyle(.secondary)
                            } else {
                                SummaryPeriodProjectChart(
                                    entries: periodProjectChartEntries,
                                    selectedPeriod: selectedPeriod,
                                    projectIDs: projectIDs
                                )
                            }
                        } header: {
                            SummarySectionHeader(
                                title: timelineTitle,
                                subtitle: selectedPeriod.timelineSubtitle
                            )
                        }
                    }

                    Section {
                        if summary.durationByProject.isEmpty {
                            Text("No time recorded in this period.")
                                .foregroundStyle(.secondary)
                        } else {
                            SummarySpaceBreakdown(
                                summaries: summary.durationByProject,
                                projectIDs: projectIDs
                            )
                        }
                    } header: {
                        SummarySectionHeader(
                            title: "By Space",
                            subtitle: summary.durationByProject.isEmpty
                                ? nil
                                : "Ranked by recorded time"
                        )
                    }
                }
                .scrollContentBackground(.hidden)
                .background(TickPalette.appBackground)
            }
            .navigationTitle("Summaries")
        }
    }
}

private struct SummaryPeriodProjectChart: View {
    let entries: [TickPeriodProjectChartEntry]
    let selectedPeriod: SummaryPeriod
    let projectIDs: [TickProject.ID]

    var body: some View {
        Chart(entries) { entry in
            BarMark(
                x: .value("Period", entry.date, unit: selectedPeriod.timelineComponent),
                y: .value("Duration", entry.hours)
            )
            .foregroundStyle(TickProjectAccent.color(for: entry.projectID, among: projectIDs))
            .accessibilityLabel(accessibilityLabel(for: entry))
            .accessibilityValue(TickDurationFormatter.shortString(from: entry.duration))
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: selectedPeriod.timelineComponent)) { value in
                AxisGridLine()
                AxisTick()
                if let date = value.as(Date.self), shouldShowAxisLabel(for: date) {
                    AxisValueLabel {
                        Text(date, format: axisLabelFormat)
                            .font(.caption2.monospacedDigit())
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                    }
                }
            }
        }
        .chartYAxisLabel("Hours")
        .frame(minHeight: 220)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(chartAccessibilityLabel)
    }

    private var axisLabelFormat: Date.FormatStyle {
        switch selectedPeriod {
        case .day:
            .dateTime.day()
        case .week:
            .dateTime.weekday(.narrow)
        case .month:
            .dateTime.day()
        case .year:
            .dateTime.month(.abbreviated)
        case .lifetime:
            .dateTime.year()
        }
    }

    private func shouldShowAxisLabel(for date: Date) -> Bool {
        switch selectedPeriod {
        case .day:
            return false
        case .week:
            return true
        case .month:
            let calendar = Calendar.current
            let day = calendar.component(.day, from: date)
            let lastDay = calendar.range(of: .day, in: .month, for: date)?.count ?? 31

            return day == 1 || day == lastDay || (day.isMultiple(of: 5) && day <= lastDay - 3)
        case .year:
            return Calendar.current.component(.month, from: date) % 2 == 1
        case .lifetime:
            return true
        }
    }

    private var chartAccessibilityLabel: String {
        let details = entries.map { entry in
            "\(entry.date.formatted(date: .abbreviated, time: .omitted)) \(entry.projectName) \(TickDurationFormatter.shortString(from: entry.duration))"
        }.joined(separator: ", ")

        return "\(selectedPeriod.timelineTitle ?? "Time") chart, \(details)."
    }

    private func accessibilityLabel(for entry: TickPeriodProjectChartEntry) -> String {
        let date = entry.date.formatted(date: .abbreviated, time: .omitted)
        return "\(entry.projectName), \(date)"
    }
}

private struct SummaryHeroCard: View {
    let periodTitle: String
    let totalDuration: TimeInterval
    let sessionCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(periodTitle, systemImage: "calendar")
                .font(.headline)
                .foregroundStyle(TickPalette.primaryAction)

            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline, spacing: 16) {
                    durationText

                    Spacer(minLength: 16)

                    sessionCountText
                }

                VStack(alignment: .leading, spacing: 8) {
                    durationText
                    sessionCountText
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .tickCard(tint: TickPalette.primaryAction)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(periodTitle) summary, \(TickDurationFormatter.shortString(from: totalDuration)), \(sessionCount) sessions")
    }

    private var durationText: some View {
        Text(TickDurationFormatter.shortString(from: totalDuration))
            .font(.system(.largeTitle, design: .rounded).weight(.bold))
            .monospacedDigit()
            .minimumScaleFactor(0.75)
            .lineLimit(1)
    }

    private var sessionCountText: some View {
        Text("\(sessionCount) \(sessionCount == 1 ? "session" : "sessions")")
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: true, vertical: false)
    }
}

private struct SummarySectionHeader: View {
    let title: String
    let subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.primary)

            if let subtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .textCase(nil)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

private struct SummarySpaceBreakdown: View {
    let summaries: [ProjectDurationSummary]
    let projectIDs: [TickProject.ID]

    private let columns = [
        GridItem(.adaptive(minimum: 260), spacing: 12)
    ]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 12) {
            ForEach(summaries) { summary in
                SummarySpaceMetric(
                    projectName: summary.projectName,
                    duration: summary.duration,
                    maximumDuration: summaries.first?.duration ?? 0,
                    color: TickProjectAccent.color(for: summary.projectID, among: projectIDs)
                )
            }
        }
        .padding(.vertical, 4)
    }
}

private struct SummarySpaceMetric: View {
    let projectName: String
    let duration: TimeInterval
    let maximumDuration: TimeInterval
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                TickProjectBadge(color: color)

                Text(projectName)
                    .lineLimit(2)

                Spacer(minLength: 8)

                Text(TickDurationFormatter.shortString(from: duration))
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: true, vertical: false)
            }

            ProgressView(value: progress)
                .tint(color)
                .accessibilityHidden(true)
        }
        .padding(12)
        .background(TickPalette.appBackground, in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(projectName)
        .accessibilityValue(TickDurationFormatter.shortString(from: duration))
    }

    private var progress: Double {
        guard maximumDuration > 0 else {
            return 0
        }

        return duration / maximumDuration
    }
}

private extension SummaryPeriod {
    var timelineSubtitle: String {
        switch self {
        case .day:
            ""
        case .week, .month:
            "Recorded time across each day"
        case .year:
            "Recorded time across each month"
        case .lifetime:
            "Recorded time across each year"
        }
    }
}

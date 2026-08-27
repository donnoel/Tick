import Charts
import SwiftUI

struct SummariesView: View {
    let viewModel: TickViewModel
    @State private var selectedPeriod = SummaryPeriod.day

    var body: some View {
        NavigationStack {
            TimelineView(.periodic(from: .now, by: 60)) { timeline in
                let summary = viewModel.summary(for: selectedPeriod, at: timeline.date)
                let projectChartEntries = TickChartDataBuilder.projectEntries(
                    for: selectedPeriod,
                    projects: viewModel.projects,
                    sessions: viewModel.sessions,
                    referenceDate: timeline.date
                )
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

                    Section("Time by Space") {
                        if projectChartEntries.isEmpty {
                            Text("No time recorded in this period.")
                                .foregroundStyle(.secondary)
                        } else {
                            Chart(projectChartEntries) { entry in
                                BarMark(
                                    x: .value("Duration", entry.hours),
                                    y: .value("Space", entry.projectName)
                                )
                                .foregroundStyle(TickProjectAccent.color(for: entry.projectID, among: projectIDs))
                                .accessibilityLabel(entry.projectName)
                                .accessibilityValue(TickDurationFormatter.shortString(from: entry.duration))
                            }
                            .chartXAxisLabel("Hours")
                            .frame(minHeight: 220)
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel(projectChartAccessibilityLabel(for: projectChartEntries))
                        }
                    }

                    if let timelineTitle = selectedPeriod.timelineTitle {
                        Section(timelineTitle) {
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
                        }
                    }

                    Section("By Space") {
                        if summary.durationByProject.isEmpty {
                            Text("No time recorded in this period.")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(summary.durationByProject) { projectSummary in
                                SummaryProjectRow(
                                    projectName: projectSummary.projectName,
                                    value: TickDurationFormatter.shortString(from: projectSummary.duration),
                                    color: TickProjectAccent.color(for: projectSummary.projectID, among: projectIDs)
                                )
                            }
                        }
                    }
                }
                .scrollContentBackground(.hidden)
                .background(TickPalette.appBackground)
            }
            .navigationTitle("Summaries")
        }
    }

    private func projectChartAccessibilityLabel(for entries: [TickProjectChartEntry]) -> String {
        let details = entries.map { entry in
            "\(entry.projectName) \(TickDurationFormatter.shortString(from: entry.duration))"
        }.joined(separator: ", ")

        return "Time by Space chart, \(details)."
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
        VStack(alignment: .leading, spacing: 12) {
            Label(periodTitle, systemImage: "calendar")
                .font(.headline)
                .foregroundStyle(TickPalette.primaryAction)

            Text(TickDurationFormatter.shortString(from: totalDuration))
                .font(.system(.largeTitle, design: .rounded).weight(.bold))
                .monospacedDigit()
                .minimumScaleFactor(0.75)
                .lineLimit(1)

            Text("\(sessionCount) \(sessionCount == 1 ? "session" : "sessions")")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .tickCard(tint: TickPalette.primaryAction)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(periodTitle) summary, \(TickDurationFormatter.shortString(from: totalDuration)), \(sessionCount) sessions")
    }
}

private struct SummaryProjectRow: View {
    let projectName: String
    let value: String
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            TickProjectBadge(color: color)

            Text(projectName)

            Spacer()

            Text(value)
                .font(.body.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }
}

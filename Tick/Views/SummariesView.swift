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
                let dayProjectChartEntries = TickChartDataBuilder.dayProjectEntries(
                    for: selectedPeriod,
                    projects: viewModel.projects,
                    sessions: viewModel.sessions,
                    referenceDate: timeline.date
                )

                List {
                    Section {
                        Picker("Period", selection: $selectedPeriod) {
                            ForEach(SummaryPeriod.allCases) { period in
                                Text(period.title).tag(period)
                            }
                        }
                        .pickerStyle(.segmented)
                        .accessibilityHint("Choose daily, weekly, or monthly summary.")
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
                                .foregroundStyle(TickProjectAccent.color(for: entry.projectID))
                                .accessibilityLabel(entry.projectName)
                                .accessibilityValue(TickDurationFormatter.shortString(from: entry.duration))
                            }
                            .chartXAxisLabel("Hours")
                            .frame(minHeight: 220)
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel(projectChartAccessibilityLabel(for: projectChartEntries))
                        }
                    }

                    if selectedPeriod != .day {
                        Section("Time by Day") {
                            if dayProjectChartEntries.isEmpty {
                                    Text("No time recorded in this period.")
                                    .foregroundStyle(.secondary)
                            } else {
                                SummaryDayProjectChart(
                                    entries: dayProjectChartEntries,
                                    selectedPeriod: selectedPeriod
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
                                    projectID: projectSummary.projectID,
                                    projectName: projectSummary.projectName,
                                    value: TickDurationFormatter.shortString(from: projectSummary.duration)
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

private struct SummaryDayProjectChart: View {
    let entries: [TickDayProjectChartEntry]
    let selectedPeriod: SummaryPeriod

    var body: some View {
        Chart(entries) { entry in
            BarMark(
                x: .value("Day", entry.date, unit: .day),
                y: .value("Duration", entry.hours)
            )
            .foregroundStyle(TickProjectAccent.color(for: entry.projectID))
            .accessibilityLabel(accessibilityLabel(for: entry))
            .accessibilityValue(TickDurationFormatter.shortString(from: entry.duration))
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .day)) { _ in
                AxisGridLine()
                AxisTick()
                AxisValueLabel(format: axisLabelFormat)
            }
        }
        .chartYAxisLabel("Hours")
        .frame(minHeight: 220)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(chartAccessibilityLabel)
    }

    private var axisLabelFormat: Date.FormatStyle {
        selectedPeriod == .week ? .dateTime.weekday(.narrow) : .dateTime.day()
    }

    private var chartAccessibilityLabel: String {
        let details = entries.map { entry in
            "\(entry.date.formatted(date: .abbreviated, time: .omitted)) \(entry.projectName) \(TickDurationFormatter.shortString(from: entry.duration))"
        }.joined(separator: ", ")

        return "Time by Day chart, \(details)."
    }

    private func accessibilityLabel(for entry: TickDayProjectChartEntry) -> String {
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
    let projectID: TickProject.ID
    let projectName: String
    let value: String

    var body: some View {
        HStack(spacing: 12) {
            TickProjectBadge(color: TickProjectAccent.color(for: projectID))

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

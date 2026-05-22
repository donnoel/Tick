import SwiftUI

struct SummariesView: View {
    let viewModel: TickViewModel
    @State private var selectedPeriod = SummaryPeriod.day

    var body: some View {
        NavigationStack {
            TimelineView(.periodic(from: .now, by: 60)) { timeline in
                let summary = viewModel.summary(for: selectedPeriod, at: timeline.date)

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

                    Section(selectedPeriod.title) {
                        SummaryMetricRow(
                            label: "Total Time",
                            value: TickDurationFormatter.shortString(from: summary.totalDuration)
                        )
                        SummaryMetricRow(
                            label: "Sessions",
                            value: "\(summary.sessionCount)"
                        )
                    }

                    Section("By Project") {
                        if summary.durationByProject.isEmpty {
                            Text("No time tracked in this period.")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(summary.durationByProject) { projectSummary in
                                SummaryMetricRow(
                                    label: projectSummary.projectName,
                                    value: TickDurationFormatter.shortString(from: projectSummary.duration)
                                )
                            }
                        }
                    }
                }
            }
            .navigationTitle("Summaries")
        }
    }
}

private struct SummaryMetricRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            Text(value)
                .font(.body.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }
}

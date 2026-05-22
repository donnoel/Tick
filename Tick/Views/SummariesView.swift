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
                    .listRowBackground(Color.clear)

                    Section {
                        SummaryHeroCard(
                            periodTitle: selectedPeriod.title,
                            totalDuration: summary.totalDuration,
                            sessionCount: summary.sessionCount
                        )
                    }
                    .listRowBackground(Color.clear)

                    Section("By Project") {
                        if summary.durationByProject.isEmpty {
                            Text("No time tracked in this period.")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(summary.durationByProject) { projectSummary in
                                SummaryProjectRow(
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

    var body: some View {
        HStack(spacing: 12) {
            TickProjectBadge(color: TickProjectAccent.color(for: projectName))

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

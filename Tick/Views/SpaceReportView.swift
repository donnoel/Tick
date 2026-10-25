import SwiftUI

struct SpaceReportView: View {
    let viewModel: TickViewModel
    let projectID: TickProject.ID
    let projectName: String
    @State private var startDate: Date
    @State private var endDate: Date
    @State private var includeNotes = true

    init(
        viewModel: TickViewModel,
        projectID: TickProject.ID,
        projectName: String,
        period: SummaryPeriod,
        referenceDate: Date
    ) {
        self.viewModel = viewModel
        self.projectID = projectID
        self.projectName = projectName
        let range = TickReportDateRange.initial(
            period: period, projectID: projectID, sessions: viewModel.sessions, referenceDate: referenceDate
        )
        _startDate = State(initialValue: range.start)
        _endDate = State(initialValue: range.end)
    }

    var body: some View {
        Group {
            if hasRunningSessionInRange {
                TimelineView(.periodic(from: .now, by: 60)) { timeline in
                    reportList(at: timeline.date)
                }
            } else {
                reportList(at: .now)
            }
        }
        .navigationTitle("Space Report")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var hasRunningSessionInRange: Bool {
        let range = TickReportDateRange(start: startDate, end: endDate)
        return viewModel.activeSessions.contains { session in
            session.projectID == projectID && !session.isPaused && range.contains(session.referenceDate)
        }
    }

    private func reportList(at date: Date) -> some View {
        let report = TickSpaceReport(
            projectID: projectID,
            projectName: viewModel.project(for: projectID)?.name ?? projectName,
            range: TickReportDateRange(start: startDate, end: endDate),
            sessions: viewModel.sessions,
            generatedAt: date,
            includeNotes: includeNotes
        )

        return List {
            Section {
                DatePicker("From", selection: $startDate, in: ...endDate, displayedComponents: .date)
                    .accessibilityIdentifier("spaceReport.fromDate")
                DatePicker("Through", selection: $endDate, in: startDate..., displayedComponents: .date)
                    .accessibilityIdentifier("spaceReport.throughDate")
                Toggle("Include session notes", isOn: $includeNotes)
                    .accessibilityHint("Includes notes in both this report and the shared text.")
                    .accessibilityIdentifier("spaceReport.includeNotes")
            } header: {
                Text("Reporting period")
            } footer: {
                Text("Both dates are included. Share sends the report shown below, including any visible notes.")
            }

            Section {
                VStack(alignment: .leading, spacing: 10) {
                    Text(report.projectName)
                        .font(.headline)
                    Text(report.range.title)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(TickSpaceReport.durationText(report.totalDuration))
                        .font(.system(.largeTitle, design: .rounded).bold())
                        .monospacedDigit()
                        .accessibilityIdentifier("spaceReport.total")
                    Text("\(report.sessionCount) \(report.sessionCount == 1 ? "session" : "sessions") · \(report.days.count) \(report.days.count == 1 ? "day" : "days")")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    if report.activeSessionCount > 0 {
                        Label("Includes running or paused time as of \(report.generatedAt.formatted(date: .omitted, time: .shortened)).", systemImage: "clock")
                            .font(.footnote)
                    }
                }
                .padding(.vertical, 8)
                .textSelection(.enabled)
            }

            if report.entries.isEmpty {
                ContentUnavailableView("No time recorded", systemImage: "calendar", description: Text("Choose another date range to review work for this space."))
            } else {
                Section {
                    ForEach(report.work) { work in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(work.id.title)
                                .font(.headline)
                            Text("\(TickSpaceReport.durationText(work.duration)) · \(work.sessionCount) \(work.sessionCount == 1 ? "session" : "sessions")")
                                .font(.subheadline.monospacedDigit())
                                .foregroundStyle(.secondary)
                            if !work.id.notes.isEmpty {
                                Text(work.id.notes)
                                    .font(.subheadline)
                            }
                        }
                        .padding(.vertical, 4)
                        .textSelection(.enabled)
                        .accessibilityElement(children: .combine)
                    }
                } header: {
                    Text("Work summary")
                } footer: {
                    Text("Recorded descriptions grouped by matching title\(includeNotes ? " and notes" : "").")
                }

                ForEach(report.days) { day in
                    Section {
                        ForEach(day.entries) { entry in
                            reportEntry(entry)
                        }
                    } header: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(day.id, format: .dateTime.weekday(.wide).month(.abbreviated).day().year())
                            Text(TickSpaceReport.durationText(day.duration))
                        }
                        .textCase(nil)
                        .accessibilityElement(children: .combine)
                        .accessibilityAddTraits(.isHeader)
                    }
                }
            }
        }
        .accessibilityIdentifier("spaceReport.list")
        .tickScreenBackground()
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                ShareLink(item: report.sharedText, subject: Text(report.subject)) {
                    Label("Share Report", systemImage: "square.and.arrow.up")
                }
                .disabled(report.entries.isEmpty)
                .accessibilityHint("Shares this space's dates, total time, work summary, and sessions using Mail or another app.")
                .accessibilityIdentifier("spaceReport.share")
            }
        }
    }

    private func reportEntry(_ entry: TickSpaceReport.Entry) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(entry.description.title)
                .font(.body.weight(.semibold))
            Text(TickSpaceReport.durationText(entry.duration))
                .font(.subheadline.monospacedDigit())
            Text(entry.status == "Manual" ? "Manual time" : "\(entry.date.formatted(date: .omitted, time: .shortened)) · \(entry.status)")
                .font(.caption)
                .foregroundStyle(.secondary)
            if !entry.description.notes.isEmpty {
                Text(entry.description.notes)
                    .font(.subheadline)
            }
        }
        .padding(.vertical, 4)
        .textSelection(.enabled)
        .accessibilityElement(children: .combine)
    }
}

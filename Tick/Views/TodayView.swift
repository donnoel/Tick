import SwiftUI

struct TodayView: View {
    @Bindable var viewModel: TickViewModel
    @State private var isAddingTime = false

    var body: some View {
        NavigationStack {
            TimelineView(.periodic(from: .now, by: 1)) { timeline in
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        totalHeader(at: timeline.date)

                        projectSelector
                        actionButtons
                        todaySessions(at: timeline.date)
                    }
                    .padding()
                }
                .background(TickPalette.appBackground)
            }
            .navigationTitle("Start Ticking")
            .sheet(isPresented: $isAddingTime) {
                ManualTimeEntryView(viewModel: viewModel)
            }
        }
    }

    private func totalHeader(at date: Date) -> some View {
        TodayHeroCard(
            totalDuration: viewModel.totalDuration(on: date, at: date),
            activeSession: viewModel.activeSession,
            activeProjectName: viewModel.activeSession.map { projectName(for: $0.projectID) },
            displayDate: date
        )
    }

    private var projectSelector: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Project")
                .font(.headline)

            if viewModel.activeProjects.isEmpty {
                ContentUnavailableView(
                    "No Projects",
                    systemImage: "folder.badge.plus",
                    description: Text("Add a project from the Projects tab to start tracking time.")
                )
                .frame(maxWidth: .infinity)
            } else {
                Picker("Project", selection: $viewModel.selectedProjectID) {
                    ForEach(viewModel.activeProjects) { project in
                        Text(project.name).tag(Optional(project.id))
                    }
                }
                .pickerStyle(.menu)
                .accessibilityHint("Choose the project for the next timer session.")
            }
        }
    }

    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button {
                Task {
                    if viewModel.activeSession == nil {
                        await viewModel.startTick()
                    } else {
                        await viewModel.stopTick()
                    }
                }
            } label: {
                Label(actionTitle, systemImage: viewModel.activeSession == nil ? "play.fill" : "stop.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(viewModel.activeSession == nil ? TickPalette.primaryAction : TickPalette.running)
            .disabled(viewModel.activeSession == nil && viewModel.selectedProjectID == nil)
            .accessibilityIdentifier("today.startStopButton")
            .accessibilityHint(actionAccessibilityHint)

            Button {
                isAddingTime = true
            } label: {
                Label("Add Time", systemImage: "plus.circle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .tint(TickPalette.primaryAction)
            .disabled(viewModel.activeProjects.isEmpty)
            .accessibilityIdentifier("today.addTimeButton")
            .accessibilityHint("Add time manually when you forgot to start Tick.")
        }
    }

    private func todaySessions(at date: Date) -> some View {
        let sessions = viewModel.sessions(on: date)
        let fallbackTitles = SessionFallbackTitleProvider.untitledSessionTitles(for: sessions)

        return VStack(alignment: .leading, spacing: 12) {
            Text("Today's Ticks")
                .font(.headline)
                .accessibilityIdentifier("today.sessionsHeader")

            if sessions.isEmpty {
                Text("No time tracked yet today.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 12)
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(sessions) { session in
                        NavigationLink {
                            SessionDetailView(viewModel: viewModel, session: session)
                        } label: {
                            SessionRowView(
                                session: session,
                                projectID: session.projectID,
                                projectName: projectName(for: session.projectID),
                                displayDate: date,
                                defaultTitle: fallbackTitles[session.id] ?? "Tick"
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("Opens session details.")
                    }
                }
            }
        }
    }

    private var actionTitle: String {
        viewModel.activeSession == nil ? "Start Tick" : "Stop Tick"
    }

    private var actionAccessibilityHint: String {
        if viewModel.activeSession == nil {
            return "Starts a timer immediately for the selected project."
        }

        return "Stops the active timer session."
    }

    private func projectName(for projectID: TickProject.ID) -> String {
        viewModel.project(for: projectID)?.name ?? "Unknown Project"
    }

    private func untitledSessionFallbackTitles(for sessions: [TimeSession]) -> [TimeSession.ID: String] {
        Dictionary(
            uniqueKeysWithValues: sessions
                .filter { $0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                .enumerated()
                .map { index, session in
                    (session.id, "\(index + 1) Tick")
                }
        )
    }
}

private struct TodayHeroCard: View {
    let totalDuration: TimeInterval
    let activeSession: TimeSession?
    let activeProjectName: String?
    let displayDate: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Label(activeSession == nil ? "Today’s Total" : "Running", systemImage: activeSession == nil ? "clock" : "timer")
                    .font(.headline)
                    .foregroundStyle(activeSession == nil ? TickPalette.primaryAction : TickPalette.running)

                Spacer()

                if let activeProjectName {
                    Text(activeProjectName)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Text(primaryDuration)
                .font(.system(.largeTitle, design: .rounded).weight(.bold))
                .monospacedDigit()
                .minimumScaleFactor(0.75)
                .lineLimit(1)

            Text(secondaryText)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .tickCard(tint: activeSession == nil ? TickPalette.primaryAction : TickPalette.running, isHighlighted: activeSession != nil)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    private var primaryDuration: String {
        if let activeSession {
            return TickDurationFormatter.timerString(from: activeSession.duration(at: displayDate))
        }

        return TickDurationFormatter.timerString(from: totalDuration)
    }

    private var secondaryText: String {
        if activeSession != nil {
            return "Today's total: \(TickDurationFormatter.shortString(from: totalDuration))"
        }

        return "Ready for your next Tick"
    }

    private var accessibilityLabel: String {
        if let activeSession {
            return "Running Tick, elapsed \(TickDurationFormatter.shortString(from: activeSession.duration(at: displayDate))), \(secondaryText)"
        }

        return "Today's total tracked time, \(TickDurationFormatter.shortString(from: totalDuration))"
    }
}

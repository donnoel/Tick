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
            Text("Space")
                .font(.headline)

            if viewModel.activeProjects.isEmpty {
                ContentUnavailableView(
                    "No Spaces",
                    systemImage: "folder.badge.plus",
                    description: Text("Add a space from the Spaces tab to start ticking.")
                )
                .frame(maxWidth: .infinity)
            } else {
                Picker("Space", selection: $viewModel.selectedProjectID) {
                    ForEach(viewModel.activeProjects) { project in
                        Text(project.name).tag(Optional(project.id))
                    }
                }
                .pickerStyle(.menu)
                .accessibilityHint("Choose the space for the next timer session.")
            }
        }
    }

    private var actionButtons: some View {
        HStack(spacing: 14) {
            TimerIconButton(
                systemImage: "play.fill",
                title: playTitle,
                tint: TickPalette.primaryAction,
                isProminent: canPlay
            ) {
                Task {
                    if viewModel.activeSession?.isPaused == true {
                        await viewModel.resumeTick()
                    } else {
                        await viewModel.startTick()
                    }
                }
            }
            .disabled(!canPlay)
            .accessibilityIdentifier("today.playButton")
            .accessibilityHint(playAccessibilityHint)

            TimerIconButton(
                systemImage: "pause.fill",
                title: "Pause Tick",
                tint: TickPalette.running,
                isProminent: canPause
            ) {
                Task {
                    await viewModel.pauseTick()
                }
            }
            .disabled(!canPause)
            .accessibilityIdentifier("today.pauseButton")
            .accessibilityHint("Pauses the active Tick without recording the paused time.")

            TimerIconButton(
                systemImage: "stop.fill",
                title: "Stop Tick",
                tint: TickPalette.running,
                isProminent: canStop
            ) {
                Task {
                    await viewModel.stopTick()
                }
            }
            .disabled(!canStop)
            .accessibilityIdentifier("today.stopButton")
            .accessibilityHint("Stops and saves the active Tick session.")

            Spacer()

            Button {
                isAddingTime = true
            } label: {
                Image(systemName: "plus.circle")
                    .font(.title3)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.bordered)
            .tint(TickPalette.primaryAction)
            .disabled(viewModel.activeProjects.isEmpty)
            .accessibilityIdentifier("today.addTimeButton")
            .accessibilityLabel("Add Time")
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
                Text("No time recorded yet today.")
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

    private var canPlay: Bool {
        viewModel.activeSession?.isPaused == true ||
            (viewModel.activeSession == nil && viewModel.selectedProjectID != nil)
    }

    private var canPause: Bool {
        guard let activeSession = viewModel.activeSession else {
            return false
        }

        return !activeSession.isPaused
    }

    private var canStop: Bool {
        viewModel.activeSession != nil
    }

    private var playTitle: String {
        viewModel.activeSession?.isPaused == true ? "Resume Tick" : "Start Tick"
    }

    private var playAccessibilityHint: String {
        if viewModel.activeSession?.isPaused == true {
            return "Resumes the paused Tick."
        }

        return "Starts a timer immediately for the selected space."
    }

    private func projectName(for projectID: TickProject.ID) -> String {
        viewModel.project(for: projectID)?.name ?? "Unknown Space"
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
                Label(statusTitle, systemImage: statusSystemImage)
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
            let status = activeSession.isPaused ? "Paused Tick" : "Running Tick"
            return "\(status), elapsed \(TickDurationFormatter.shortString(from: activeSession.duration(at: displayDate))), \(secondaryText)"
        }

        return "Today's total recorded time, \(TickDurationFormatter.shortString(from: totalDuration))"
    }

    private var statusTitle: String {
        guard let activeSession else {
            return "Today’s Total"
        }

        return activeSession.isPaused ? "Paused" : "Running"
    }

    private var statusSystemImage: String {
        guard let activeSession else {
            return "clock"
        }

        return activeSession.isPaused ? "pause.circle" : "timer"
    }
}

private struct TimerIconButton: View {
    let systemImage: String
    let title: String
    let tint: Color
    let isProminent: Bool
    let action: () -> Void

    var body: some View {
        if isProminent {
            button
                .buttonStyle(.borderedProminent)
                .clipShape(Circle())
                .tint(tint)
                .accessibilityLabel(title)
        } else {
            button
                .buttonStyle(.bordered)
                .clipShape(Circle())
                .tint(tint)
                .accessibilityLabel(title)
        }
    }

    private var button: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.title3.weight(.semibold))
                .frame(width: 50, height: 50)
        }
    }
}

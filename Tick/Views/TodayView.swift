import SwiftUI

struct TodayView: View {
    @Bindable var viewModel: TickViewModel
    @State private var isAddingTime = false

    var body: some View {
        NavigationStack {
            TimelineView(.periodic(from: .now, by: 1)) { timeline in
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        todayHeader(at: timeline.date)
                        totalHeader(at: timeline.date)

                        projectSelector
                        actionButtons
                        todaySessions(at: timeline.date)
                    }
                    .frame(maxWidth: 980, alignment: .leading)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal)
                    .padding(.vertical, 12)
                }
                .background(TodayBackground())
            }
            .navigationTitle("Start Ticking")
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $isAddingTime) {
                ManualTimeEntryView(viewModel: viewModel)
            }
        }
    }

    private func todayHeader(at date: Date) -> some View {
        TodayHeader(displayDate: date)
    }

    private func totalHeader(at date: Date) -> some View {
        TodayHeroCard(
            totalDuration: viewModel.totalDuration(on: date, at: date),
            activeSession: viewModel.activeSession,
            displayDate: date
        )
    }

    private var projectSelector: some View {
        let selectedProjectID = viewModel.selectedProjectID ?? viewModel.activeProjects.first?.id
        let selectedAccent = selectedProjectID.map {
            TickProjectAccent.color(for: $0, among: viewModel.projects.map(\.id))
        } ?? TickPalette.primaryAction

        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                TickProjectBadge(color: selectedAccent, systemImage: "folder.fill")

                VStack(alignment: .leading, spacing: 2) {
                    Text("Space")
                        .font(.headline)

                    Text(selectedSpaceSubtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            if viewModel.activeProjects.isEmpty {
                HStack(spacing: 10) {
                    Image(systemName: "folder.badge.plus")
                        .font(.title2)
                        .foregroundStyle(selectedAccent)
                        .frame(width: 38, height: 38)
                        .background(selectedAccent.opacity(0.12), in: Circle())

                    Text("Add a space from the Spaces tab to start ticking.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.top, 2)
            } else {
                Picker("Space", selection: $viewModel.selectedProjectID) {
                    ForEach(viewModel.activeProjects) { project in
                        Text(project.name).tag(Optional(project.id))
                    }
                }
                .pickerStyle(.menu)
                .tint(selectedAccent)
                .accessibilityHint("Choose the space for the next timer session.")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .tickCard(tint: selectedAccent)
    }

    private var actionButtons: some View {
        HStack(spacing: 14) {
            HStack(spacing: 12) {
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
            }
            .padding(8)
            .background(.thinMaterial, in: Capsule())

            Spacer()

            Button {
                isAddingTime = true
            } label: {
                Label("Add Time", systemImage: "plus")
                    .labelStyle(.iconOnly)
                    .font(.title3.weight(.semibold))
                    .frame(width: 52, height: 52)
            }
            .buttonStyle(.borderedProminent)
            .clipShape(Circle())
            .tint(TickPalette.primaryAction)
            .disabled(viewModel.activeProjects.isEmpty)
            .accessibilityIdentifier("today.addTimeButton")
            .accessibilityLabel("Add Time")
            .accessibilityHint("Add time manually when you forgot to start Tick.")
        }
        .padding(12)
        .tickCard(tint: viewModel.activeSession == nil ? TickPalette.primaryAction : TickPalette.running, isHighlighted: viewModel.activeSession != nil)
        .padding(.bottom, 4)
    }

    private func todaySessions(at date: Date) -> some View {
        let sessions = viewModel.sessions(on: date)
        let fallbackTitles = SessionFallbackTitleProvider.untitledSessionTitles(for: sessions)
        let projectIDs = viewModel.projects.map(\.id)

        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Today's Ticks")
                    .font(.headline)
                    .accessibilityIdentifier("today.sessionsHeader")

                Spacer()

                Text("\(sessions.count)")
                    .font(.caption.weight(.bold))
                    .monospacedDigit()
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(TickPalette.primaryAction.opacity(0.14), in: Capsule())
                    .foregroundStyle(TickPalette.primaryAction)
                    .accessibilityLabel("\(sessions.count) sessions today")
            }

            if sessions.isEmpty {
                Label("No time recorded yet today.", systemImage: "clock.badge")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .tickCard(tint: TickPalette.primaryAction)
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
                                defaultTitle: fallbackTitles[session.id] ?? "Tick",
                                accentColor: TickProjectAccent.color(for: session.projectID, among: projectIDs)
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

    private var selectedSpaceSubtitle: String {
        if viewModel.activeProjects.isEmpty {
            return "Add one before ticking"
        }

        if viewModel.activeSession != nil {
            return "Catching time right now"
        }

        return "Ready for the next Tick"
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

private struct TodayHeader: View {
    let displayDate: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Start Ticking")
                .font(.largeTitle.weight(.bold))
                .minimumScaleFactor(0.78)
                .lineLimit(1)

            Text(displayDate.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 22)
        .padding(.horizontal, 14)
        .padding(.bottom, 14)
        .background {
            LinearGradient(
                colors: [
                    TickPalette.primaryAction.opacity(0.10),
                    Color.cyan.opacity(0.06),
                    Color.clear
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .clipShape(RoundedRectangle(cornerRadius: 18))
        }
    }
}

private struct TodayHeroCard: View {
    let totalDuration: TimeInterval
    let activeSession: TimeSession?
    let displayDate: Date

    var body: some View {
        ZStack(alignment: .topTrailing) {
            TodayTickTrail(tint: tint)
                .padding(.top, 14)
                .padding(.trailing, 12)

            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .firstTextBaseline) {
                    Label(statusTitle, systemImage: statusSystemImage)
                        .font(.headline)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(tint.opacity(0.14), in: Capsule())
                        .foregroundStyle(tint)

                    Spacer()
                }

                Text(primaryDuration)
                    .font(.system(size: 46, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .minimumScaleFactor(0.68)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Image(systemName: secondarySystemImage)
                        .foregroundStyle(tint)

                    Text(secondaryText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background {
            RoundedRectangle(cornerRadius: 14)
                .fill(
                    LinearGradient(
                        colors: [
                            tint.opacity(activeSession == nil ? 0.16 : 0.22),
                            Color.cyan.opacity(0.10),
                            TickPalette.cardBackground
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(tint.opacity(activeSession == nil ? 0.18 : 0.36), lineWidth: 1)
                }
        }
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

    private var secondarySystemImage: String {
        activeSession == nil ? "play.circle" : "chart.line.uptrend.xyaxis"
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

    private var tint: Color {
        activeSession == nil ? TickPalette.primaryAction : TickPalette.running
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

private struct TodayBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color.blue.opacity(0.08),
                Color.pink.opacity(0.06),
                TickPalette.appBackground
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}

private struct TodayTickTrail: View {
    let tint: Color

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<5) { index in
                Capsule()
                    .fill(tint.opacity(0.16 + Double(index) * 0.04))
                    .frame(width: 8, height: CGFloat(16 + index * 4))
            }
        }
        .rotationEffect(.degrees(-18))
        .accessibilityHidden(true)
    }
}

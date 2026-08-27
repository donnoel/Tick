import SwiftUI

struct TodayView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @Bindable var viewModel: TickViewModel
    @State private var isAddingTime = false

    var body: some View {
        NavigationStack {
            let displayDate = Date.now
            let todaySessions = viewModel.sessions(on: displayDate)
            let fallbackTitles = SessionFallbackTitleProvider.untitledSessionTitles(for: todaySessions)
            let projectIDs = viewModel.projects.map(\.id)
            let activeSession = viewModel.activeSession

            ScrollView {
                adaptiveTodayLayout(
                    sessions: todaySessions,
                    fallbackTitles: fallbackTitles,
                    projectIDs: projectIDs,
                    activeSession: activeSession,
                    displayDate: displayDate
                )
                .frame(maxWidth: 1000, alignment: .leading)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 28)
            }
            .background(Color(.systemBackground))
            .navigationTitle("Start Ticking")
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $isAddingTime) {
                ManualTimeEntryView(viewModel: viewModel)
            }
        }
    }

    private func adaptiveTodayLayout(
        sessions: [TimeSession],
        fallbackTitles: [TimeSession.ID: String],
        projectIDs: [TickProject.ID],
        activeSession: TimeSession?,
        displayDate: Date
    ) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 40) {
                VStack(alignment: .leading, spacing: 24) {
                    todayHeader(at: displayDate)
                    captureSection(
                        sessions: sessions,
                        activeSession: activeSession,
                        displayDate: displayDate,
                        usesHorizontalActions: false
                    )
                }
                .frame(minWidth: 340, idealWidth: 380, maxWidth: 420, alignment: .leading)

                Divider()

                todaySessionsSection(
                    sessions,
                    fallbackTitles: fallbackTitles,
                    projectIDs: projectIDs,
                    displayDate: displayDate
                )
                .frame(minWidth: 380, maxWidth: .infinity, alignment: .leading)
            }

            VStack(alignment: .leading, spacing: 24) {
                todayHeader(at: displayDate)
                captureSection(
                    sessions: sessions,
                    activeSession: activeSession,
                    displayDate: displayDate,
                    usesHorizontalActions: usesWideCaptureLayout
                )
                todaySessionsSection(
                    sessions,
                    fallbackTitles: fallbackTitles,
                    projectIDs: projectIDs,
                    displayDate: displayDate
                )
            }
        }
    }

    private func todayHeader(at date: Date) -> some View {
        TodayHeader(displayDate: date)
    }

    private func captureSection(
        sessions: [TimeSession],
        activeSession: TimeSession?,
        displayDate: Date,
        usesHorizontalActions: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            captureContext(activeSession: activeSession)

            if usesHorizontalActions {
                HStack(alignment: .center, spacing: 40) {
                    timerTimeline(
                        sessions: sessions,
                        activeSession: activeSession,
                        displayDate: displayDate
                    )

                    Spacer(minLength: 12)

                    timerActions
                        .fixedSize(horizontal: true, vertical: false)
                }
            } else {
                VStack(alignment: .leading, spacing: 18) {
                    timerTimeline(
                        sessions: sessions,
                        activeSession: activeSession,
                        displayDate: displayDate
                    )

                    timerActions
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, 4)
    }

    @ViewBuilder
    private var projectSelector: some View {
        if viewModel.activeProjects.isEmpty {
            Label("Add a Space in Spaces to begin", systemImage: "folder.badge.plus")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(minHeight: 44)
                .accessibilityLabel("No Spaces available. Add a Space in the Spaces tab to begin.")
        } else {
            Menu {
                ForEach(viewModel.activeProjects) { project in
                    Button {
                        viewModel.selectedProjectID = project.id
                    } label: {
                        HStack {
                            Text(project.name)

                            if project.id == selectedProjectID {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    Circle()
                        .fill(selectedProjectAccent)
                        .frame(width: 9, height: 9)
                        .accessibilityHidden(true)

                    Text(selectedProjectName)
                        .lineLimit(1)

                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.tertiary)
                        .accessibilityHidden(true)
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .accessibilityLabel("Space, \(selectedProjectName)")
            .accessibilityHint("Choose the space for the next timer session.")
        }
    }

    private func captureContext(activeSession: TimeSession?) -> some View {
        HStack(spacing: 14) {
            projectSelector

            if let activeSession {
                HStack(spacing: 6) {
                    Circle()
                        .fill(TickPalette.running)
                        .frame(width: 7, height: 7)
                        .accessibilityHidden(true)

                    Text(activeSession.isPaused ? "Paused" : "Running")
                        .lineLimit(1)
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .accessibilityElement(children: .combine)
                .accessibilityLabel(activeSession.isPaused ? "Tick paused" : "Tick running")
            }

            Spacer(minLength: 8)

            addTimeButton
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var addTimeButton: some View {
        Button {
            isAddingTime = true
        } label: {
            ViewThatFits(in: .horizontal) {
                Label("Add Time", systemImage: "plus.circle.fill")
                Image(systemName: "plus.circle.fill")
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(TickPalette.primaryAction)
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(viewModel.activeProjects.isEmpty)
        .accessibilityIdentifier("today.addTimeButton")
        .accessibilityLabel("Add Time")
        .accessibilityHint("Add time manually when you forgot to start Tick.")
    }

    private func timerTimeline(
        sessions: [TimeSession],
        activeSession: TimeSession?,
        displayDate: Date
    ) -> some View {
        TodayTimerTimeline(
            staticTotalDuration: staticTotalDuration(from: sessions, at: displayDate),
            activeSession: activeSession,
            activeSessionCountsTowardTotal: activeSession.map { activeSession in
                sessions.contains { $0.id == activeSession.id }
            } ?? false,
            displayDate: displayDate
        )
    }

    @ViewBuilder
    private var timerActions: some View {
        if let activeSession = viewModel.activeSession {
            HStack(spacing: 12) {
                if activeSession.isPaused {
                    TimerTextButton(
                        systemImage: "play.fill",
                        title: "Resume Tick",
                        tint: TickPalette.primaryAction,
                        isProminent: true
                    ) {
                        Task {
                            await viewModel.resumeTick()
                        }
                    }
                    .accessibilityIdentifier("today.playButton")
                    .accessibilityHint("Resumes the paused Tick.")
                } else {
                    TimerTextButton(
                        systemImage: "pause.fill",
                        title: "Pause Tick",
                        tint: TickPalette.running,
                        isProminent: true
                    ) {
                        Task {
                            await viewModel.pauseTick()
                        }
                    }
                    .accessibilityIdentifier("today.pauseButton")
                    .accessibilityHint("Pauses the active Tick without recording the paused time.")
                }

                TimerTextButton(
                    systemImage: "stop.fill",
                    title: "Stop Tick",
                    tint: TickPalette.running,
                    isProminent: false,
                    minimumWidth: 100
                ) {
                    Task {
                        await viewModel.stopTick()
                    }
                }
                .accessibilityIdentifier("today.stopButton")
                .accessibilityHint("Stops and saves the active Tick session.")
            }
        } else {
            TimerTextButton(
                systemImage: "play.fill",
                title: "Start Tick",
                tint: TickPalette.primaryAction,
                isProminent: true,
                minimumWidth: 170
            ) {
                Task {
                    await viewModel.startTick()
                }
            }
            .disabled(viewModel.selectedProjectID == nil)
            .accessibilityIdentifier("today.playButton")
            .accessibilityHint("Starts a timer immediately for the selected space.")
        }
    }

    private func todaySessionsSection(
        _ sessions: [TimeSession],
        fallbackTitles: [TimeSession.ID: String],
        projectIDs: [TickProject.ID],
        displayDate: Date
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("Today's Ticks")
                    .font(.title3.weight(.semibold))
                    .accessibilityIdentifier("today.sessionsHeader")

                Spacer()

                Text(sessions.isEmpty ? "None yet" : "\(sessions.count)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .accessibilityLabel("\(sessions.count) sessions today")
            }

            if sessions.isEmpty {
                Label("No time recorded yet today", systemImage: "clock")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 14)
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(sessions) { session in
                        NavigationLink {
                            SessionDetailView(viewModel: viewModel, session: session)
                        } label: {
                            LiveSessionRowView(
                                session: session,
                                projectID: session.projectID,
                                projectName: projectName(for: session.projectID),
                                displayDate: displayDate,
                                defaultTitle: fallbackTitles[session.id] ?? "Tick",
                                accentColor: TickProjectAccent.color(for: session.projectID, among: projectIDs)
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("Opens session details.")

                        if session.id != sessions.last?.id {
                            Divider()
                                .padding(.leading, 22)
                        }
                    }
                }
            }
        }
    }

    private func staticTotalDuration(from sessions: [TimeSession], at displayDate: Date) -> TimeInterval {
        sessions.reduce(0) { total, session in
            guard !session.isActive else {
                return total
            }

            return total + session.duration(at: displayDate)
        }
    }

    private var selectedProjectID: TickProject.ID? {
        viewModel.selectedProjectID ?? viewModel.activeProjects.first?.id
    }

    private var selectedProjectName: String {
        selectedProjectID.flatMap { viewModel.project(for: $0)?.name } ?? "Choose a Space"
    }

    private var selectedProjectAccent: Color {
        guard let selectedProjectID else {
            return TickPalette.primaryAction
        }

        return TickProjectAccent.color(for: selectedProjectID, among: viewModel.projects.map(\.id))
    }

    private var usesWideCaptureLayout: Bool {
        horizontalSizeClass == .regular && !dynamicTypeSize.isAccessibilitySize
    }

    private func projectName(for projectID: TickProject.ID) -> String {
        viewModel.project(for: projectID)?.name ?? "Unknown Space"
    }
}

private struct TodayHeader: View {
    let displayDate: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("Start Ticking")
                .font(.title.weight(.bold))

            Text(displayDate.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 6)
    }
}

private struct TodayTimerDisplay: View {
    @ScaledMetric(relativeTo: .largeTitle) private var timerFontSize = 48.0

    let totalDuration: TimeInterval
    let activeSession: TimeSession?
    let displayDate: Date

    var body: some View {
        Group {
            if let activeSession {
                VStack(alignment: .leading, spacing: 5) {
                    Text(TickDurationFormatter.timerString(from: activeSession.duration(at: displayDate)))
                        .font(.system(size: timerFontSize, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .minimumScaleFactor(0.62)
                        .lineLimit(1)

                    Text("\(TickDurationFormatter.shortString(from: totalDuration)) today")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } else {
                VStack(alignment: .leading, spacing: 5) {
                    Text("\(TickDurationFormatter.shortString(from: totalDuration)) today")
                        .font(.title2.weight(.semibold))
                        .monospacedDigit()

                    Text("Ready when you are")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        if let activeSession {
            let status = activeSession.isPaused ? "Paused Tick" : "Running Tick"
            return "\(status), elapsed \(TickDurationFormatter.shortString(from: activeSession.duration(at: displayDate))), \(TickDurationFormatter.shortString(from: totalDuration)) today"
        }

        return "Today's total recorded time, \(TickDurationFormatter.shortString(from: totalDuration)). Ready when you are."
    }
}

private struct TodayTimerTimeline: View {
    let staticTotalDuration: TimeInterval
    let activeSession: TimeSession?
    let activeSessionCountsTowardTotal: Bool
    let displayDate: Date

    var body: some View {
        if let activeSession, !activeSession.isPaused {
            TimelineView(.periodic(from: .now, by: 1)) { timeline in
                timerDisplay(activeSession: activeSession, displayDate: timeline.date)
            }
        } else {
            timerDisplay(activeSession: activeSession, displayDate: displayDate)
        }
    }

    private func timerDisplay(activeSession: TimeSession?, displayDate: Date) -> some View {
        TodayTimerDisplay(
            totalDuration: totalDuration(activeSession: activeSession, displayDate: displayDate),
            activeSession: activeSession,
            displayDate: displayDate
        )
    }

    private func totalDuration(activeSession: TimeSession?, displayDate: Date) -> TimeInterval {
        guard activeSessionCountsTowardTotal, let activeSession else {
            return staticTotalDuration
        }

        return staticTotalDuration + activeSession.duration(at: displayDate)
    }
}

private struct LiveSessionRowView: View {
    let session: TimeSession
    let projectID: TickProject.ID
    let projectName: String
    let displayDate: Date
    let defaultTitle: String
    let accentColor: Color

    var body: some View {
        if session.isActive && !session.isPaused {
            TimelineView(.periodic(from: .now, by: 1)) { timeline in
                row(displayDate: timeline.date)
            }
        } else {
            row(displayDate: displayDate)
        }
    }

    private func row(displayDate: Date) -> some View {
        SessionRowView(
            session: session,
            projectID: projectID,
            projectName: projectName,
            displayDate: displayDate,
            defaultTitle: defaultTitle,
            accentColor: accentColor,
            presentation: .plain
        )
    }
}

private struct TimerTextButton: View {
    let systemImage: String
    let title: String
    let tint: Color
    let isProminent: Bool
    var minimumWidth = 124.0
    let action: () -> Void

    var body: some View {
        if isProminent {
            button
                .buttonStyle(.borderedProminent)
                .tint(tint)
        } else {
            button
                .buttonStyle(.plain)
                .foregroundStyle(tint)
        }
    }

    private var button: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.headline)
                .frame(minWidth: minimumWidth, minHeight: 46)
        }
        .clipShape(Capsule())
        .accessibilityLabel(title)
    }
}

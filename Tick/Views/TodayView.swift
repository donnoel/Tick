import SwiftUI

struct TodayView: View {
    private enum CapturePresentation {
        case compact
        case iPadHero
    }

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
                if UIDevice.current.userInterfaceIdiom == .pad {
                    iPadTodayLayout(
                        sessions: todaySessions,
                        fallbackTitles: fallbackTitles,
                        projectIDs: projectIDs,
                        activeSession: activeSession,
                        displayDate: displayDate
                    )
                    .frame(maxWidth: 1120, alignment: .leading)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, horizontalSizeClass == .compact ? 20 : 48)
                    .padding(.top, 20)
                    .padding(.bottom, 36)
                } else {
                    iPhoneTodayLayout(
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
            }
            .background(Color(.systemBackground))
            .navigationTitle("Start Ticking")
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $isAddingTime) {
                ManualTimeEntryView(viewModel: viewModel)
            }
        }
    }

    private func iPadTodayLayout(
        sessions: [TimeSession],
        fallbackTitles: [TimeSession.ID: String],
        projectIDs: [TickProject.ID],
        activeSession: TimeSession?,
        displayDate: Date
    ) -> some View {
        VStack(alignment: .leading, spacing: 32) {
            iPadCurrentTickHero(
                sessions: sessions,
                activeSession: activeSession,
                displayDate: displayDate
            )

            iPadTodaySessionsSection(
                sessions,
                fallbackTitles: fallbackTitles,
                projectIDs: projectIDs,
                displayDate: displayDate
            )
        }
    }

    private func iPadCurrentTickHero(
        sessions: [TimeSession],
        activeSession: TimeSession?,
        displayDate: Date
    ) -> some View {
        VStack(alignment: .leading, spacing: dynamicTypeSize.isAccessibilitySize ? 24 : 20) {
            HStack(alignment: .top, spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(activeSession == nil ? "Start Ticking" : "Current Tick")
                        .font(.title.weight(.bold))

                    Text(displayDate.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))
                        .font(.body)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 16)

                iPadTimerStatus(activeSession: activeSession)
            }

            projectSelector(presentation: .iPadHero)

            TodayTimerTimeline(
                staticTotalDuration: staticTotalDuration(from: sessions, at: displayDate),
                activeSession: activeSession,
                activeSessionCountsTowardTotal: activeSession.map { activeSession in
                    sessions.contains { $0.id == activeSession.id }
                } ?? false,
                displayDate: displayDate,
                presentation: .iPadHero
            )
            .frame(maxWidth: .infinity)

            timerActions(presentation: .iPadHero)

            addTimeButton(presentation: .iPadHero)
                .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 32)
        .padding(.vertical, dynamicTypeSize.isAccessibilitySize ? 28 : 24)
        .frame(maxWidth: 760)
        .background {
            RoundedRectangle(cornerRadius: 24)
                .fill(TickPalette.cardBackground)
                .overlay {
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                }
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func iPadTimerStatus(activeSession: TimeSession?) -> some View {
        if activeSession?.isPaused == true {
            iPadStatusPill(
                "Paused",
                systemImage: "pause.circle.fill",
                tint: TickPalette.running
            )
            .accessibilityLabel("Tick paused")
        } else if activeSession == nil {
            iPadStatusPill(
                "Ready",
                systemImage: "checkmark.circle.fill",
                tint: TickPalette.primaryAction
            )
            .accessibilityLabel("Ready to start a Tick")
        }
    }

    private func iPadStatusPill(_ title: String, systemImage: String, tint: Color) -> some View {
        Label(title, systemImage: systemImage)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 12)
            .frame(minHeight: 36)
            .background(tint.opacity(0.10), in: Capsule())
    }

    private func iPadTodaySessionsSection(
        _ sessions: [TimeSession],
        fallbackTitles: [TimeSession.ID: String],
        projectIDs: [TickProject.ID],
        displayDate: Date
    ) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                Text("Today's Ticks")
                    .font(.title2.weight(.bold))
                    .accessibilityIdentifier("today.sessionsHeader")

                Spacer()

                if !sessions.isEmpty {
                    Text("\(sessions.count) \(sessions.count == 1 ? "tick" : "ticks")")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                        .accessibilityLabel("\(sessions.count) \(sessions.count == 1 ? "tick" : "ticks") today")
                }
            }

            if sessions.isEmpty {
                Label("Your ticks will appear here.", systemImage: "clock")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
            } else {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 300, maximum: 352), spacing: 20, alignment: .top)],
                    alignment: .leading,
                    spacing: 18
                ) {
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
                                accentColor: TickProjectAccent.color(for: session.projectID, among: projectIDs),
                                presentation: .card
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("Opens session details.")
                    }
                }
            }
        }
    }

    private func iPhoneTodayLayout(
        sessions: [TimeSession],
        fallbackTitles: [TimeSession.ID: String],
        projectIDs: [TickProject.ID],
        activeSession: TimeSession?,
        displayDate: Date
    ) -> some View {
        VStack(alignment: .leading, spacing: 22) {
            todayHeader(at: displayDate)
            iPhoneCurrentTickSection(
                sessions: sessions,
                activeSession: activeSession,
                displayDate: displayDate
            )
            todaySessionsSection(
                sessions,
                fallbackTitles: fallbackTitles,
                projectIDs: projectIDs,
                displayDate: displayDate
            )
        }
    }

    private func todayHeader(at date: Date) -> some View {
        TodayHeader(displayDate: date)
    }

    private func iPhoneCurrentTickSection(
        sessions: [TimeSession],
        activeSession: TimeSession?,
        displayDate: Date
    ) -> some View {
        VStack(spacing: 12) {
            VStack(spacing: dynamicTypeSize.isAccessibilitySize ? 22 : 18) {
                Text(iPhoneCaptureStatus(activeSession: activeSession))
                    .font(.caption.weight(.semibold))
                    .tracking(1)
                    .foregroundStyle(activeSession == nil ? Color.secondary : selectedProjectAccent)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityHidden(true)

                projectSelector()

                timerTimeline(
                    sessions: sessions,
                    activeSession: activeSession,
                    displayDate: displayDate
                )
                .frame(maxWidth: .infinity)

                timerActions()
                    .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 20)
            .background {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(TickPalette.cardBackground)
                    .overlay {
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(selectedProjectAccent.opacity(0.055))
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(selectedProjectAccent.opacity(0.16), lineWidth: 1)
                    }
            }

            addTimeButton()
                .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 4)
    }

    private func iPhoneCaptureStatus(activeSession: TimeSession?) -> String {
        guard let activeSession else {
            return "READY TO START"
        }

        return activeSession.isPaused ? "TICK PAUSED" : "CURRENT TICK"
    }

    @ViewBuilder
    private func projectSelector(presentation: CapturePresentation = .compact) -> some View {
        if viewModel.activeProjects.isEmpty {
            if presentation == .iPadHero {
                Label("Add a Space in Spaces to begin", systemImage: "folder.badge.plus")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 58, alignment: .leading)
                    .padding(.horizontal, 18)
                    .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 16))
                    .accessibilityLabel("No Spaces available. Add a Space in the Spaces tab to begin.")
            } else {
                Label("Add a Space in Spaces to begin", systemImage: "folder.badge.plus")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    .background(Color.secondary.opacity(0.07), in: Capsule())
                    .accessibilityLabel("No Spaces available. Add a Space in the Spaces tab to begin.")
            }
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
                if presentation == .iPadHero {
                    HStack(spacing: 14) {
                        Circle()
                            .fill(selectedProjectAccent)
                            .frame(width: 14, height: 14)
                            .accessibilityHidden(true)

                        VStack(alignment: .leading, spacing: 1) {
                            Text("SPACE")
                                .font(.caption2.weight(.semibold))
                                .tracking(0.8)
                                .foregroundStyle(.secondary)

                            Text(selectedProjectName)
                                .font(.headline)
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                        }

                        Spacer(minLength: 12)

                        Image(systemName: "chevron.up.chevron.down")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .accessibilityHidden(true)
                    }
                    .padding(.horizontal, 18)
                    .frame(maxWidth: .infinity, minHeight: 58)
                    .background(selectedProjectAccent.opacity(0.07), in: RoundedRectangle(cornerRadius: 16))
                    .overlay {
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(selectedProjectAccent.opacity(0.14), lineWidth: 1)
                    }
                    .contentShape(Rectangle())
                } else {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(selectedProjectAccent)
                            .frame(width: 9, height: 9)
                            .accessibilityHidden(true)

                        Text(selectedProjectName)
                            .lineLimit(1)

                        Spacer(minLength: 4)

                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.tertiary)
                            .accessibilityHidden(true)
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 12)
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    .background(selectedProjectAccent.opacity(0.06), in: Capsule())
                    .overlay {
                        Capsule()
                            .stroke(selectedProjectAccent.opacity(0.14), lineWidth: 1)
                    }
                    .contentShape(Rectangle())
                }
            }
            .accessibilityLabel("Space, \(selectedProjectName)")
            .accessibilityHint("Choose the space for the next timer session.")
        }
    }

    private func addTimeButton(presentation: CapturePresentation = .compact) -> some View {
        Button {
            isAddingTime = true
        } label: {
            if presentation == .iPadHero {
                Label("Add Time", systemImage: "plus.circle.fill")
                    .font(.headline)
                    .foregroundStyle(TickPalette.primaryAction)
                    .frame(minWidth: 120, minHeight: 44)
                    .contentShape(Rectangle())
            } else {
                Label("Add Time", systemImage: "plus.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(TickPalette.primaryAction)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(Color.secondary.opacity(0.06), in: Capsule())
                    .overlay {
                        Capsule()
                            .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                    }
                    .contentShape(Rectangle())
            }
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
    private func timerActions(presentation: CapturePresentation = .compact) -> some View {
        if presentation == .iPadHero {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: 14) {
                    timerActionButtons(presentation: presentation)
                }
                .frame(maxWidth: .infinity)
            } else {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 14) {
                        timerActionButtons(presentation: presentation)
                    }
                    .frame(maxWidth: .infinity)

                    VStack(spacing: 14) {
                        timerActionButtons(presentation: presentation)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        } else if viewModel.activeSession != nil {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: 10) {
                    timerActionButtons(presentation: presentation)
                }
                .frame(maxWidth: .infinity)
            } else {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 12) {
                        timerActionButtons(presentation: presentation)
                    }
                    .frame(maxWidth: .infinity)

                    VStack(spacing: 10) {
                        timerActionButtons(presentation: presentation)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        } else {
            timerActionButtons(presentation: presentation)
        }
    }

    @ViewBuilder
    private func timerActionButtons(presentation: CapturePresentation) -> some View {
        if let activeSession = viewModel.activeSession {
            if activeSession.isPaused {
                TimerTextButton(
                    systemImage: "play.fill",
                    title: "Resume Tick",
                    tint: TickPalette.primaryAction,
                    isProminent: true,
                    minimumWidth: presentation == .iPadHero ? 240 : 124,
                    presentation: presentation == .iPadHero ? .iPadHero : .compact
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
                    isProminent: true,
                    minimumWidth: presentation == .iPadHero ? 240 : 124,
                    presentation: presentation == .iPadHero ? .iPadHero : .compact
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
                minimumWidth: presentation == .iPadHero ? 180 : 100,
                presentation: presentation == .iPadHero ? .iPadHero : .compact
            ) {
                Task {
                    await viewModel.stopTick()
                }
            }
            .accessibilityIdentifier("today.stopButton")
            .accessibilityHint("Stops and saves the active Tick session.")
        } else {
            TimerTextButton(
                systemImage: "play.fill",
                title: "Start Tick",
                tint: TickPalette.primaryAction,
                isProminent: true,
                minimumWidth: presentation == .iPadHero ? 240 : 170,
                presentation: presentation == .iPadHero ? .iPadHero : .compact
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

                Text(sessions.isEmpty ? "None yet" : "\(sessions.count) \(sessions.count == 1 ? "tick" : "ticks")")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .accessibilityLabel("\(sessions.count) \(sessions.count == 1 ? "tick" : "ticks") today")
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

    private func projectName(for projectID: TickProject.ID) -> String {
        viewModel.project(for: projectID)?.name ?? "Unknown Space"
    }
}

private struct TodayHeader: View {
    let displayDate: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("Today")
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
    enum Presentation {
        case compact
        case iPadHero
    }

    @ScaledMetric(relativeTo: .largeTitle) private var timerFontSize = 48.0
    @ScaledMetric(relativeTo: .largeTitle) private var iPadTimerFontSize = 72.0

    let totalDuration: TimeInterval
    let activeSession: TimeSession?
    let displayDate: Date
    var presentation: Presentation = .compact

    var body: some View {
        switch presentation {
        case .compact:
            compactDisplay
        case .iPadHero:
            iPadHeroDisplay
        }
    }

    private var compactDisplay: some View {
        VStack(spacing: 4) {
            Text(TickDurationFormatter.timerString(from: activeSession?.duration(at: displayDate) ?? 0))
                .font(.system(size: timerFontSize, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .minimumScaleFactor(0.62)
                .lineLimit(1)

            Text("Today total \(TickDurationFormatter.shortString(from: totalDuration))")
                .font(.subheadline)
                .foregroundStyle(.primary)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity)
        .multilineTextAlignment(.center)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    private var iPadHeroDisplay: some View {
        VStack(spacing: 5) {
            Text(activeSession == nil ? "TODAY'S TIME" : activeSession?.isPaused == true ? "PAUSED AT" : "ELAPSED")
                .font(.caption.weight(.semibold))
                .tracking(1.1)
                .foregroundStyle(.secondary)

            Text(timerStyleString(from: primaryDuration))
                .font(.system(size: iPadTimerFontSize, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .minimumScaleFactor(0.55)
                .lineLimit(1)

            if activeSession != nil {
                Text("Today total \(timerStyleString(from: totalDuration))")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            } else {
                Text("Ready when you are")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .multilineTextAlignment(.center)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    private var primaryDuration: TimeInterval {
        activeSession?.duration(at: displayDate) ?? totalDuration
    }

    private func timerStyleString(from duration: TimeInterval) -> String {
        let totalSeconds = max(0, Int(duration.rounded(.down)))
        let hours = totalSeconds / 3_600
        let minutes = (totalSeconds % 3_600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }

        return String(format: "%d:%02d", minutes, seconds)
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
    var presentation: TodayTimerDisplay.Presentation = .compact

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
            displayDate: displayDate,
            presentation: presentation
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
    var presentation: SessionRowView.Presentation = .plain

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
            presentation: presentation
        )
    }
}

private struct TimerTextButton: View {
    enum Presentation {
        case compact
        case iPadHero
    }

    let systemImage: String
    let title: String
    let tint: Color
    let isProminent: Bool
    var minimumWidth = 124.0
    var presentation: Presentation = .compact
    let action: () -> Void

    var body: some View {
        if isProminent && presentation == .iPadHero {
            button
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .tint(tint)
        } else if isProminent {
            button
                .buttonStyle(.borderedProminent)
                .tint(tint)
        } else if presentation == .iPadHero {
            button
                .buttonStyle(.bordered)
                .buttonBorderShape(.capsule)
                .tint(tint)
        } else {
            button
                .buttonStyle(.bordered)
                .buttonBorderShape(.capsule)
                .tint(tint)
        }
    }

    private var button: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(presentation == .iPadHero ? .title3.weight(.semibold) : .headline)
                .frame(
                    minWidth: minimumWidth,
                    maxWidth: presentation == .iPadHero ? (isProminent ? 300 : 260) : nil,
                    minHeight: presentation == .iPadHero ? 58 : 46
                )
        }
        .clipShape(Capsule())
        .accessibilityLabel(title)
    }
}

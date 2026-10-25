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
    @State private var selectedSession: TimeSession?
    @State private var sessionPendingDeletion: TimeSession?
    @State private var deletionMessage: String?

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
            .tickScreenBackground()
            .navigationTitle("Start Ticking")
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $isAddingTime) {
                ManualTimeEntryView(viewModel: viewModel)
            }
            .navigationDestination(item: $selectedSession) { session in
                SessionDetailView(viewModel: viewModel, session: session)
            }
            .alert("Delete Tick?", isPresented: sessionDeletionConfirmationIsPresented, presenting: sessionPendingDeletion) { session in
                Button("Delete Tick", role: .destructive) {
                    deleteSession(id: session.id)
                }
                Button("Cancel", role: .cancel) {}
            } message: { session in
                let title = session.title.trimmingCharacters(in: .whitespacesAndNewlines)
                let name = title.isEmpty ? "This Tick" : "“\(title)”"
                Text("\(name) and its recorded time will be permanently deleted. This cannot be undone.")
            }
            .alert("Could Not Delete", isPresented: deletionAlertIsPresented) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(deletionMessage ?? "Tick could not delete that session.")
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
        VStack(alignment: .leading, spacing: 20) {
            todayHeader(at: displayDate)
            capturePanel(sessions: sessions, activeSession: activeSession, displayDate: displayDate)
        }
        .frame(maxWidth: 760)
        .frame(maxWidth: .infinity)
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
                    columns: [GridItem(.adaptive(minimum: 300), spacing: 20, alignment: .top)],
                    alignment: .leading,
                    spacing: 18
                ) {
                    ForEach(sessions) { session in
                        todaySessionRow(
                            session,
                            fallbackTitle: fallbackTitles[session.id] ?? "Tick",
                            projectIDs: projectIDs,
                            displayDate: displayDate,
                            presentation: .card
                        )
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
        capturePanel(sessions: sessions, activeSession: activeSession, displayDate: displayDate)
    }

    private func capturePanel(
        sessions: [TimeSession],
        activeSession: TimeSession?,
        displayDate: Date
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            projectSelector()

            ViewThatFits(in: .horizontal) {
                HStack(alignment: .center, spacing: 20) {
                    timerTimeline(sessions: sessions, activeSession: activeSession, displayDate: displayDate)
                        .fixedSize(horizontal: true, vertical: false)
                    Spacer(minLength: 0)
                    panelActions()
                        .fixedSize(horizontal: true, vertical: false)
                }
                VStack(alignment: .leading, spacing: 16) {
                    timerTimeline(sessions: sessions, activeSession: activeSession, displayDate: displayDate)
                    panelActions()
                }
            }

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) {
                    addTimeButton()
                    Spacer(minLength: 0)
                    timerTimeline(sessions: sessions, activeSession: activeSession, displayDate: displayDate, presentation: .totalOnly)
                        .fixedSize(horizontal: true, vertical: false)
                }
                VStack(alignment: .leading, spacing: 4) {
                    addTimeButton()
                    timerTimeline(sessions: sessions, activeSession: activeSession, displayDate: displayDate, presentation: .totalOnly)
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 18)
                .fill(TickPalette.cardBackground)
                .overlay {
                    RoundedRectangle(cornerRadius: 18)
                        .fill(LinearGradient(
                            colors: [.blue.opacity(0.10), .mint.opacity(0.12), .pink.opacity(0.07)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.primary.opacity(0.10), lineWidth: 1)
        }
    }

    private func panelActions() -> some View {
        VStack(alignment: .trailing, spacing: 8) {
            timerActionButtons(presentation: .compact)
        }
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
                ForEach(viewModel.alphabeticalActiveProjects) { project in
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
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                    Spacer(minLength: 0)
                }
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .accessibilityLabel("Space, \(selectedProjectName)")
            .accessibilityHint("Choose the space for the next timer session.")
        }
    }

    private func addTimeButton() -> some View {
        Button {
            isAddingTime = true
        } label: {
            Label("Add Time", systemImage: "plus")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(TickPalette.primaryAction)
                .frame(minHeight: 44)
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
        displayDate: Date,
        presentation: TodayTimerDisplay.Presentation = .compact
    ) -> some View {
        TodayTimerTimeline(
            staticTotalDuration: staticTotalDuration(from: sessions, at: displayDate),
            activeSession: activeSession,
            activeSessionCountsTowardTotal: activeSession.map { activeSession in
                sessions.contains { $0.id == activeSession.id }
            } ?? false,
            displayDate: displayDate,
            presentation: presentation
        )
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
                    minimumWidth: presentation == .iPadHero ? 240 : 84,
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
                    minimumWidth: presentation == .iPadHero ? 240 : 84,
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
                minimumWidth: presentation == .iPadHero ? 240 : 84,
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
                        todaySessionRow(
                            session,
                            fallbackTitle: fallbackTitles[session.id] ?? "Tick",
                            projectIDs: projectIDs,
                            displayDate: displayDate,
                            presentation: .plain
                        )

                        if session.id != sessions.last?.id {
                            Divider()
                                .padding(.leading, 22)
                        }
                    }
                }
            }
        }
    }

    private func todaySessionRow(
        _ session: TimeSession,
        fallbackTitle: String,
        projectIDs: [TickProject.ID],
        displayDate: Date,
        presentation: SessionRowView.Presentation
    ) -> some View {
        TodaySessionSwipeRow(canDelete: !session.isActive) {
            sessionPendingDeletion = session
        } content: {
            LiveSessionRowView(
                session: session,
                projectID: session.projectID,
                projectName: projectName(for: session.projectID),
                displayDate: displayDate,
                defaultTitle: fallbackTitle,
                accentColor: TickProjectAccent.color(for: session.projectID, among: projectIDs),
                presentation: presentation
            )
            .contentShape(Rectangle())
            .onTapGesture {
                selectedSession = session
            }
            .accessibilityAddTraits(.isButton)
            .accessibilityAction(.default) {
                selectedSession = session
            }
            .accessibilityIdentifier("today.sessionRow.\(session.id.uuidString)")
            .accessibilityHint(session.isActive
                ? "Opens session details. Stop this Tick before deleting it."
                : "Opens session details. Swipe left for Delete.")
        }
    }

    private var sessionDeletionConfirmationIsPresented: Binding<Bool> {
        Binding {
            sessionPendingDeletion != nil
        } set: { isPresented in
            if !isPresented { sessionPendingDeletion = nil }
        }
    }

    private var deletionAlertIsPresented: Binding<Bool> {
        Binding {
            deletionMessage != nil
        } set: { isPresented in
            if !isPresented { deletionMessage = nil }
        }
    }

    private func deleteSession(id: TimeSession.ID) {
        Task {
            guard await viewModel.deleteSession(id: id) else {
                deletionMessage = viewModel.errorMessage ?? "Tick could not delete that session."
                return
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

private struct TodaySessionSwipeRow<Content: View>: View {
    private let actionWidth: CGFloat = 96

    let canDelete: Bool
    let onDelete: () -> Void
    let content: Content

    @State private var isRevealed = false
    @State private var dragOffset: CGFloat = 0

    init(canDelete: Bool, onDelete: @escaping () -> Void, @ViewBuilder content: () -> Content) {
        self.canDelete = canDelete
        self.onDelete = onDelete
        self.content = content()
    }

    @ViewBuilder
    var body: some View {
        if canDelete {
            ZStack(alignment: .trailing) {
                Button(action: requestDelete) {
                    Label("Delete", systemImage: "trash")
                        .font(.subheadline.weight(.semibold))
                        .frame(width: actionWidth)
                        .frame(minHeight: 44)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white)
                .background(.red, in: RoundedRectangle(cornerRadius: 12))
                .accessibilityIdentifier("today.deleteButton")
                .accessibilityHidden(!isRevealed)

                content
                    .offset(x: visibleOffset)
                    .simultaneousGesture(swipeGesture)
                    .accessibilityAction(named: Text("Delete Tick")) {
                        requestDelete()
                    }
            }
            .clipped()
        } else {
            content
        }
    }

    private var visibleOffset: CGFloat {
        min(0, max(-actionWidth, (isRevealed ? -actionWidth : 0) + dragOffset))
    }

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 20)
            .onChanged { value in
                guard abs(value.translation.width) > abs(value.translation.height) else { return }
                dragOffset = value.translation.width
            }
            .onEnded { value in
                guard abs(value.translation.width) > abs(value.translation.height) else {
                    dragOffset = 0
                    return
                }
                withAnimation(.easeOut(duration: 0.18)) {
                    isRevealed = value.translation.width < -40 || (isRevealed && value.translation.width < 40)
                    dragOffset = 0
                }
            }
    }

    private func requestDelete() {
        isRevealed = false
        onDelete()
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
        case totalOnly
    }

    @ScaledMetric(relativeTo: .largeTitle) private var timerFontSize = 44.0
    let totalDuration: TimeInterval
    let activeSession: TimeSession?
    let displayDate: Date
    var presentation: Presentation = .compact

    var body: some View {
        if presentation == .totalOnly {
            Text("Today total \(TickDurationFormatter.timerString(from: totalDuration))")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        } else {
            VStack(alignment: .leading, spacing: 3) {
                if let activeSession {
                    Text(activeSession.isPaused ? "Paused" : "Running")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                Text(TickDurationFormatter.timerString(from: activeSession?.duration(at: displayDate) ?? 0))
                    .font(.system(size: timerFontSize, weight: .medium))
                    .monospacedDigit()
                    .minimumScaleFactor(0.62)
                    .lineLimit(1)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(accessibilityLabel)
        }
    }

    private var accessibilityLabel: String {
        if let activeSession {
            let status = activeSession.isPaused ? "Paused Tick" : "Running Tick"
            return "\(status), elapsed \(TickDurationFormatter.shortString(from: activeSession.duration(at: displayDate)))"
        }
        return "Ready to start a Tick"
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
    var minimumWidth = 84.0
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
                .font(presentation == .iPadHero ? .title3.weight(.semibold) : .subheadline.weight(.semibold))
                .frame(
                    minWidth: minimumWidth,
                    maxWidth: presentation == .iPadHero ? (isProminent ? 300 : 260) : nil,
                    minHeight: presentation == .iPadHero ? 58 : 28
                )
        }
        .frame(minHeight: 44)
        .clipShape(Capsule())
        .accessibilityLabel(title)
    }
}

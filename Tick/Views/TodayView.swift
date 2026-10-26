import SwiftUI

struct TodayView: View {
    private enum CapturePresentation {
        case compact
        case iPadHero
    }

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage(TickUIStateStorage.todayTimerOrderKey) private var timerOrder = ""

    @Bindable var viewModel: TickViewModel
    @State private var isAddingTime = false
    @State private var manualProjectID: TickProject.ID?
    @State private var secondProjectID: TickProject.ID?
    @State private var isSecondTimerExpanded = false
    @State private var selectedSession: TimeSession?
    @State private var sessionPendingDeletion: TimeSession?
    @State private var deletionMessage: String?

    var body: some View {
        NavigationStack {
            let displayDate = Date.now
            let todaySessions = viewModel.sessions(on: displayDate)
            let fallbackTitles = SessionFallbackTitleProvider.untitledSessionTitles(for: todaySessions)
            let projectIDs = viewModel.projects.map(\.id)

            ScrollView {
                if UIDevice.current.userInterfaceIdiom == .pad {
                    iPadTodayLayout(
                        sessions: todaySessions,
                        fallbackTitles: fallbackTitles,
                        projectIDs: projectIDs,
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
                ManualTimeEntryView(viewModel: viewModel, initialProjectID: manualProjectID)
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
        displayDate: Date
    ) -> some View {
        VStack(alignment: .leading, spacing: 32) {
            iPadCurrentTickHero(
                sessions: sessions,
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
        displayDate: Date
    ) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            todayHeader(at: displayDate)
            capturePanels(sessions: sessions, displayDate: displayDate)
        }
        .frame(maxWidth: 1120)
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
                            presentation: .iPadGrid
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
        displayDate: Date
    ) -> some View {
        VStack(alignment: .leading, spacing: 22) {
            todayHeader(at: displayDate)
            iPhoneCurrentTickSection(
                sessions: sessions,
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
        displayDate: Date
    ) -> some View {
        capturePanels(sessions: sessions, displayDate: displayDate)
    }

    private func capturePanels(sessions: [TimeSession], displayDate: Date) -> some View {
        let active = viewModel.activeSessions
        let primaryID = active.first?.projectID ?? selectedProjectID
        let secondOptions = viewModel.alphabeticalActiveProjects.filter { $0.id != primaryID }
        let secondaryID = active.dropFirst().first?.projectID
            ?? secondOptions.first(where: { $0.id == secondProjectID })?.id
            ?? secondOptions.first(where: { timerOrder.contains($0.id.uuidString) })?.id
            ?? secondOptions.first?.id
        let isReversed = primaryID.flatMap { primaryID in
            secondaryID.map { timerOrder == "\($0.uuidString)|\(primaryID.uuidString)" }
        } ?? false

        return Group {
            if UIDevice.current.userInterfaceIdiom == .pad {
                HStack(alignment: .top, spacing: 16) {
                    if isReversed, let secondaryID {
                        reorderableTimerCard(sessions: sessions, projectID: secondaryID,
                                             activeSession: active.dropFirst().first,
                                             displayDate: displayDate, isSecondary: true,
                                             otherProjectID: primaryID, isFirst: true)
                    }
                    reorderableTimerCard(sessions: sessions, projectID: primaryID,
                                         activeSession: active.first, displayDate: displayDate,
                                         isSecondary: false, otherProjectID: secondaryID,
                                         isFirst: !isReversed)
                    if !isReversed, let secondaryID {
                        reorderableTimerCard(sessions: sessions, projectID: secondaryID,
                                             activeSession: active.dropFirst().first,
                                             displayDate: displayDate, isSecondary: true,
                                             otherProjectID: primaryID, isFirst: false)
                    }
                }
            } else {
                VStack(spacing: 12) {
                    if isReversed, let secondaryID {
                        reorderableTimerCard(sessions: sessions, projectID: secondaryID,
                                             activeSession: active.dropFirst().first,
                                             displayDate: displayDate, isSecondary: true,
                                             otherProjectID: primaryID, isFirst: true)
                    }
                    reorderableTimerCard(sessions: sessions, projectID: primaryID,
                                         activeSession: active.first, displayDate: displayDate,
                                         isSecondary: false, otherProjectID: secondaryID,
                                         isFirst: !isReversed)
                    if !isReversed, let secondaryID {
                        reorderableTimerCard(sessions: sessions, projectID: secondaryID,
                                             activeSession: active.dropFirst().first,
                                             displayDate: displayDate, isSecondary: true,
                                             otherProjectID: primaryID, isFirst: false)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func reorderableTimerCard(
        sessions: [TimeSession], projectID: TickProject.ID?, activeSession: TimeSession?,
        displayDate: Date, isSecondary: Bool, otherProjectID: TickProject.ID?, isFirst: Bool
    ) -> some View {
        if let projectID, let otherProjectID {
            timerCard(sessions: sessions, projectID: projectID, activeSession: activeSession,
                      displayDate: displayDate, isSecondary: isSecondary, isFirst: isFirst,
                      dragItem: projectID.uuidString)
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier(isSecondary ? "today.timerCard.secondary" : "today.timerCard")
                .dropDestination(for: String.self) { items, _ in
                    guard items.contains(otherProjectID.uuidString) else { return false }
                    swapTimerCards(topProjectID: isFirst ? projectID : otherProjectID,
                                   bottomProjectID: isFirst ? otherProjectID : projectID)
                    return true
                }
                .accessibilityAction(named: Text(isFirst ? "Move timer down" : "Move timer up")) {
                    swapTimerCards(topProjectID: isFirst ? projectID : otherProjectID,
                                   bottomProjectID: isFirst ? otherProjectID : projectID)
                }
        } else {
            timerCard(sessions: sessions, projectID: projectID, activeSession: activeSession,
                      displayDate: displayDate, isSecondary: isSecondary, isFirst: isFirst,
                      dragItem: nil)
        }
    }

    @ViewBuilder
    private func timerCard(
        sessions: [TimeSession], projectID: TickProject.ID?, activeSession: TimeSession?,
        displayDate: Date, isSecondary: Bool, isFirst: Bool, dragItem: String?
    ) -> some View {
        if UIDevice.current.userInterfaceIdiom == .phone, !isFirst,
           activeSession == nil, !isSecondTimerExpanded, let projectID {
            collapsedSecondTimer(projectID: projectID, dragItem: dragItem)
        } else {
            capturePanel(sessions: sessions, projectID: projectID, activeSession: activeSession,
                         displayDate: displayDate, isSecondary: isSecondary,
                         showsCollapseButton: UIDevice.current.userInterfaceIdiom == .phone
                             && !isFirst && activeSession == nil,
                         dragItem: dragItem)
        }
    }

    private func swapTimerCards(topProjectID: TickProject.ID, bottomProjectID: TickProject.ID) {
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.22)) {
            timerOrder = "\(bottomProjectID.uuidString)|\(topProjectID.uuidString)"
        }
    }

    private func collapsedSecondTimer(projectID: TickProject.ID, dragItem: String?) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) { isSecondTimerExpanded = true }
        } label: {
            HStack(spacing: 10) {
                Circle()
                    .fill(TickProjectAccent.color(for: projectID, among: viewModel.projects.map(\.id)))
                    .frame(width: 9, height: 9)
                    .accessibilityHidden(true)
                Text(projectName(for: projectID))
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Spacer(minLength: 8)
                Text("Start another Tick")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let dragItem {
                    Image(systemName: "line.3.horizontal")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 28, height: 44)
                        .contentShape(Rectangle())
                        .draggable(dragItem)
                        .accessibilityIdentifier("today.timerDragHandle.secondary")
                        .accessibilityLabel("Reorder \(projectName(for: projectID)) timer")
                        .accessibilityHint("Drag to change the timer order.")
                }
                Image(systemName: "chevron.down")
                    .font(.caption.weight(.semibold))
                    .accessibilityHidden(true)
            }
            .foregroundStyle(.primary)
            .frame(minHeight: 44)
            .padding(.horizontal, 18)
            .background(TickPalette.cardBackground, in: RoundedRectangle(cornerRadius: 18))
            .overlay {
                RoundedRectangle(cornerRadius: 18)
                    .stroke(Color.primary.opacity(0.10), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("today.secondTimer.expand")
        .accessibilityLabel("Expand \(projectName(for: projectID)) timer")
        .accessibilityHint("Shows the second Space timer and its Start Tick button.")
    }

    private func capturePanel(
        sessions: [TimeSession],
        projectID: TickProject.ID?,
        activeSession: TimeSession?,
        displayDate: Date,
        isSecondary: Bool,
        showsCollapseButton: Bool = false,
        dragItem: String? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                projectSelector(projectID: projectID, activeSession: activeSession, isSecondary: isSecondary)
                if let dragItem {
                    Image(systemName: "line.3.horizontal")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 28, height: 44)
                        .contentShape(Rectangle())
                        .draggable(dragItem)
                        .accessibilityIdentifier(isSecondary
                            ? "today.timerDragHandle.secondary" : "today.timerDragHandle")
                        .accessibilityLabel("Reorder timer")
                        .accessibilityHint("Drag to change the timer order.")
                }
                if showsCollapseButton {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { isSecondTimerExpanded = false }
                    } label: {
                        Image(systemName: "chevron.up")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("today.secondTimer.collapse")
                    .accessibilityLabel("Collapse second timer")
                    .accessibilityHint("Hides the unused timer controls on iPhone.")
                }
            }

            ViewThatFits(in: .horizontal) {
                HStack(alignment: .center, spacing: 20) {
                    timerTimeline(sessions: sessions, activeSession: activeSession,
                                  displayDate: displayDate)
                        .fixedSize(horizontal: true, vertical: false)
                    Spacer(minLength: 0)
                    panelActions(activeSession: activeSession, projectID: projectID, isSecondary: isSecondary)
                        .fixedSize(horizontal: true, vertical: false)
                }
                VStack(alignment: .leading, spacing: 16) {
                    timerTimeline(sessions: sessions, activeSession: activeSession,
                                  displayDate: displayDate)
                    panelActions(activeSession: activeSession, projectID: projectID, isSecondary: isSecondary)
                }
            }

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) {
                    addTimeButton(projectID: projectID, isSecondary: isSecondary)
                    Spacer(minLength: 0)
                    timerTimeline(sessions: sessions, activeSession: activeSession,
                                  displayDate: displayDate, presentation: .totalOnly)
                        .fixedSize(horizontal: true, vertical: false)
                }
                VStack(alignment: .leading, spacing: 4) {
                    addTimeButton(projectID: projectID, isSecondary: isSecondary)
                    timerTimeline(sessions: sessions, activeSession: activeSession,
                                  displayDate: displayDate, presentation: .totalOnly)
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

    private func panelActions(activeSession: TimeSession?, projectID: TickProject.ID?,
                              isSecondary: Bool) -> some View {
        Group {
            if UIDevice.current.userInterfaceIdiom == .pad {
                HStack(spacing: 8) {
                    timerActionButtons(activeSession: activeSession, projectID: projectID,
                                       isSecondary: isSecondary, presentation: .compact)
                }
            } else {
                VStack(alignment: .trailing, spacing: 8) {
                    timerActionButtons(activeSession: activeSession, projectID: projectID,
                                       isSecondary: isSecondary, presentation: .compact)
                }
            }
        }
    }

    @ViewBuilder
    private func projectSelector(projectID: TickProject.ID?, activeSession: TimeSession?, isSecondary: Bool,
                                 presentation: CapturePresentation = .compact) -> some View {
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
                ForEach(viewModel.alphabeticalActiveProjects.filter { project in
                    project.id == projectID || !viewModel.activeSessions.contains(where: { $0.projectID == project.id })
                }) { project in
                    Button {
                        if isSecondary { secondProjectID = project.id }
                        else { viewModel.selectedProjectID = project.id }
                    } label: {
                        HStack {
                            Text(project.name)

                            if project.id == projectID {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    Circle()
                    .fill(projectID.map { TickProjectAccent.color(for: $0, among: viewModel.projects.map(\.id)) }
                          ?? TickPalette.primaryAction)
                        .frame(width: 9, height: 9)
                        .accessibilityHidden(true)
                    Text(projectID.flatMap { viewModel.project(for: $0)?.name } ?? "Choose a Space")
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
            .disabled(activeSession != nil)
            .accessibilityLabel("Space, \(projectID.flatMap { viewModel.project(for: $0)?.name } ?? "Choose a Space")")
            .accessibilityHint("Choose the space for the next timer session.")
        }
    }

    private func addTimeButton(projectID: TickProject.ID?, isSecondary: Bool) -> some View {
        Button {
            manualProjectID = projectID
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
        .accessibilityIdentifier(isSecondary ? "today.addTimeButton.secondary" : "today.addTimeButton")
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
            activeSessions: viewModel.activeSessions.filter { active in
                sessions.contains { $0.id == active.id }
            },
            displayDate: displayDate,
            presentation: presentation
        )
    }

    @ViewBuilder
    private func timerActionButtons(activeSession: TimeSession?, projectID: TickProject.ID?, isSecondary: Bool,
                                    presentation: CapturePresentation) -> some View {
        let spaceName = projectID.flatMap { viewModel.project(for: $0)?.name } ?? "Space"
        if let activeSession {
            if activeSession.isPaused {
                TimerTextButton(
                    systemImage: "play.fill",
                    title: UIDevice.current.userInterfaceIdiom == .pad ? "Resume" : "Resume Tick",
                    tint: TickPalette.primaryAction,
                    isProminent: true,
                    minimumWidth: presentation == .iPadHero ? 240 : 84,
                    presentation: presentation == .iPadHero ? .iPadHero : .compact
                ) {
                    Task {
                        await viewModel.resumeTick(sessionID: activeSession.id)
                    }
                }
                .accessibilityIdentifier(isSecondary ? "today.playButton.secondary" : "today.playButton")
                .accessibilityLabel("Resume Tick")
                .accessibilityValue(spaceName)
                .accessibilityHint("Resumes the paused Tick.")
            } else {
                TimerTextButton(
                    systemImage: "pause.fill",
                    title: UIDevice.current.userInterfaceIdiom == .pad ? "Pause" : "Pause Tick",
                    tint: TickPalette.running,
                    isProminent: true,
                    minimumWidth: presentation == .iPadHero ? 240 : 84,
                    presentation: presentation == .iPadHero ? .iPadHero : .compact
                ) {
                    Task {
                        await viewModel.pauseTick(sessionID: activeSession.id)
                    }
                }
                .accessibilityIdentifier(isSecondary ? "today.pauseButton.secondary" : "today.pauseButton")
                .accessibilityLabel("Pause Tick")
                .accessibilityValue(spaceName)
                .accessibilityHint("Pauses the active Tick without recording the paused time.")
            }

            TimerTextButton(
                systemImage: "stop.fill",
                title: UIDevice.current.userInterfaceIdiom == .pad ? "Stop" : "Stop Tick",
                tint: TickPalette.running,
                isProminent: false,
                minimumWidth: presentation == .iPadHero ? 180 : (UIDevice.current.userInterfaceIdiom == .pad ? 84 : 100),
                presentation: presentation == .iPadHero ? .iPadHero : .compact
            ) {
                Task {
                    if await viewModel.stopTick(sessionID: activeSession.id) {
                        isSecondTimerExpanded = false
                    }
                }
            }
            .accessibilityIdentifier(isSecondary ? "today.stopButton.secondary" : "today.stopButton")
            .accessibilityLabel("Stop Tick")
            .accessibilityValue(spaceName)
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
                    await viewModel.startTick(projectID: projectID)
                }
            }
            .disabled(projectID == nil || viewModel.activeSessions.count >= 2)
            .accessibilityIdentifier(isSecondary ? "today.playButton.secondary" : "today.playButton")
            .accessibilityLabel("Start Tick")
            .accessibilityValue(spaceName)
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

    private func projectName(for projectID: TickProject.ID) -> String {
        viewModel.project(for: projectID)?.name ?? "Unknown Space"
    }
}

private struct TodaySessionSwipeRow<Content: View>: View {
    private let actionWidth: CGFloat = 96

    private enum DragAxis {
        case horizontal
        case vertical
    }

    let canDelete: Bool
    let onDelete: () -> Void
    let content: Content

    @State private var isRevealed = false
    @State private var dragOffset: CGFloat = 0
    @State private var dragAxis: DragAxis?

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
                .opacity(visibleOffset < 0 ? 1 : 0)
                .allowsHitTesting(isRevealed)

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
                if dragAxis == nil {
                    dragAxis = abs(value.translation.width) > abs(value.translation.height)
                        ? .horizontal : .vertical
                }
                guard dragAxis == .horizontal else { return }
                dragOffset = value.translation.width
            }
            .onEnded { value in
                guard dragAxis == .horizontal else {
                    dragAxis = nil
                    dragOffset = 0
                    return
                }
                withAnimation(.easeOut(duration: 0.18)) {
                    isRevealed = value.translation.width < -40 || (isRevealed && value.translation.width < 40)
                    dragOffset = 0
                }
                dragAxis = nil
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
                } else if UIDevice.current.userInterfaceIdiom == .pad {
                    Text("Running")
                        .font(.caption.weight(.medium))
                        .hidden()
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
    let activeSessions: [TimeSession]
    let displayDate: Date
    var presentation: TodayTimerDisplay.Presentation = .compact

    var body: some View {
        if activeSessions.contains(where: { !$0.isPaused }) {
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
        return staticTotalDuration + activeSessions.reduce(0) { $0 + $1.duration(at: displayDate) }
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

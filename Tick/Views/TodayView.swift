import SwiftUI

struct TodayView: View {
    @Bindable var viewModel: TickViewModel
    @State private var presentedSheet: TodaySheet?

    var body: some View {
        NavigationStack {
            TimelineView(.periodic(from: .now, by: 1)) { timeline in
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        totalHeader(at: timeline.date)

                        if let activeSession = viewModel.activeSession {
                            ActiveTimerCard(
                                session: activeSession,
                                projectName: projectName(for: activeSession.projectID),
                                displayDate: timeline.date
                            )
                        }

                        projectSelector
                        actionButtons
                        todaySessions(at: timeline.date)
                    }
                    .padding()
                }
            }
            .navigationTitle("Today")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        presentedSheet = .addProject
                    } label: {
                        Label("Add Project", systemImage: "folder.badge.plus")
                    }
                    .accessibilityHint("Create a new project.")
                }
            }
            .sheet(item: $presentedSheet) { sheet in
                switch sheet {
                case .addProject:
                    AddProjectView(viewModel: viewModel)
                case .addTime:
                    ManualTimeEntryView(viewModel: viewModel)
                }
            }
        }
    }

    private func totalHeader(at date: Date) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Today")
                .font(.title2.weight(.semibold))

            Text(TickDurationFormatter.timerString(from: viewModel.totalDuration(on: date, at: date)))
                .font(.system(.largeTitle, design: .rounded).weight(.semibold))
                .monospacedDigit()
                .accessibilityLabel("Today's total tracked time")
                .accessibilityValue(TickDurationFormatter.shortString(from: viewModel.totalDuration(on: date, at: date)))
        }
    }

    private var projectSelector: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Project")
                .font(.headline)

            if viewModel.activeProjects.isEmpty {
                ContentUnavailableView(
                    "No Projects",
                    systemImage: "folder.badge.plus",
                    description: Text("Add a project to start tracking time.")
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
            .disabled(viewModel.activeSession == nil && viewModel.selectedProjectID == nil)
            .accessibilityHint(actionAccessibilityHint)

            Button {
                presentedSheet = .addTime
            } label: {
                Label("Add Time", systemImage: "plus.circle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .disabled(viewModel.activeProjects.isEmpty)
            .accessibilityHint("Add time manually when you forgot to start Tick.")
        }
    }

    private func todaySessions(at date: Date) -> some View {
        let sessions = viewModel.sessions(on: date)

        return VStack(alignment: .leading, spacing: 12) {
            Text("Today's Ticks")
                .font(.headline)

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
                                projectName: projectName(for: session.projectID),
                                displayDate: date
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
}

private enum TodaySheet: Identifiable {
    case addProject
    case addTime

    var id: Int {
        switch self {
        case .addProject:
            1
        case .addTime:
            2
        }
    }
}

private struct ActiveTimerCard: View {
    let session: TimeSession
    let projectName: String
    let displayDate: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Running", systemImage: "timer")
                .font(.headline)
                .foregroundStyle(.tint)

            Text(TickDurationFormatter.timerString(from: session.duration(at: displayDate)))
                .font(.system(.largeTitle, design: .rounded).weight(.semibold))
                .monospacedDigit()
                .accessibilityLabel("Active timer elapsed time")
                .accessibilityValue(TickDurationFormatter.shortString(from: session.duration(at: displayDate)))

            Text(projectName)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
        .accessibilityElement(children: .combine)
    }
}

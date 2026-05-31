import SwiftUI

struct ProjectDetailView: View {
    let viewModel: TickViewModel
    let project: TickProject
    @State private var deletionMessage: String?
    @State private var projectActionMessage: String?

    var body: some View {
        let currentProject = viewModel.project(for: project.id) ?? project
        let projectAccent = TickProjectAccent.color(for: currentProject.id, among: viewModel.projects.map(\.id))

        TimelineView(.periodic(from: .now, by: 60)) { timeline in
            List {
                Section {
                    ProjectSummaryCard(
                        project: currentProject,
                        duration: viewModel.totalDuration(for: currentProject.id, at: timeline.date),
                        color: projectAccent
                    )
                }
                .listRowBackground(Color.clear)

                if currentProject.isArchived {
                    Section {
                        Label("This space is archived.", systemImage: "archivebox")
                            .font(.subheadline)
                            .accessibilityLabel("Space status: archived.")
                    }
                }

                Section("Space") {
                    if currentProject.isArchived {
                        Button {
                            restoreProject(currentProject.id)
                        } label: {
                            Label("Restore Space", systemImage: "arrow.uturn.backward.circle")
                        }
                        .accessibilityHint("Moves this space back to Active Spaces.")
                    } else {
                        Button {
                            archiveProject(currentProject.id)
                        } label: {
                            Label("Archive Space", systemImage: "archivebox")
                        }
                        .accessibilityHint("Moves this space to Archived Spaces without deleting it.")
                    }
                }

                Section("Sessions") {
                    let projectSessions = viewModel.sessions(for: currentProject.id)
                    if projectSessions.isEmpty {
                        ContentUnavailableView(
                            "No Ticks yet",
                            systemImage: "clock",
                            description: Text("Sessions for this space will appear here.")
                        )
                    } else {
                        ForEach(projectSessions) { session in
                            NavigationLink {
                                SessionDetailView(viewModel: viewModel, session: session)
                            } label: {
                                SessionRowView(
                                    session: session,
                                    projectID: currentProject.id,
                                    projectName: currentProject.name,
                                    displayDate: timeline.date,
                                    defaultTitle: SessionFallbackTitleProvider.fallbackTitle(for: session, in: projectSessions),
                                    detailStyle: .date,
                                    accentColor: projectAccent
                                )
                            }
                            .buttonStyle(.plain)
                            .accessibilityHint("Opens session details.")
                        }
                        .onDelete { indexSet in
                            deleteSessions(at: indexSet, from: projectSessions)
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(TickPalette.appBackground)
        }
        .navigationTitle(currentProject.name)
        .navigationBarTitleDisplayMode(.inline)
        .alert("Could Not Delete", isPresented: deletionAlertIsPresented) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(deletionMessage ?? "Tick could not delete that session.")
        }
        .alert("Could Not Update Space", isPresented: projectActionAlertIsPresented) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(projectActionMessage ?? "Tick could not update that space.")
        }
    }

    private var deletionAlertIsPresented: Binding<Bool> {
        Binding {
            deletionMessage != nil
        } set: { isPresented in
            if !isPresented {
                deletionMessage = nil
            }
        }
    }

    private var projectActionAlertIsPresented: Binding<Bool> {
        Binding {
            projectActionMessage != nil
        } set: { isPresented in
            if !isPresented {
                projectActionMessage = nil
            }
        }
    }

    private func deleteSessions(at indexSet: IndexSet, from sessions: [TimeSession]) {
        Task {
            for index in indexSet {
                let didDelete = await viewModel.deleteSession(id: sessions[index].id)
                if !didDelete {
                    deletionMessage = viewModel.errorMessage ?? "Tick could not delete that session."
                    return
                }
            }
        }
    }

    private func archiveProject(_ projectID: TickProject.ID) {
        Task {
            let didArchive = await viewModel.archiveProject(id: projectID)
            if !didArchive {
                projectActionMessage = viewModel.errorMessage ?? "Tick could not archive that space."
            }
        }
    }

    private func restoreProject(_ projectID: TickProject.ID) {
        Task {
            let didRestore = await viewModel.restoreProject(id: projectID)
            if !didRestore {
                projectActionMessage = viewModel.errorMessage ?? "Tick could not restore that space."
            }
        }
    }
}

private struct ProjectSummaryCard: View {
    let project: TickProject
    let duration: TimeInterval
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                TickProjectBadge(color: color, systemImage: "folder.fill")

                VStack(alignment: .leading, spacing: 4) {
                    Text(project.name)
                        .font(.headline)

                    Text("Created \(project.createdAt.formatted(date: .abbreviated, time: .omitted))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Text(TickDurationFormatter.shortString(from: duration))
                .font(.system(.largeTitle, design: .rounded).weight(.bold))
                .monospacedDigit()
                .minimumScaleFactor(0.75)
                .lineLimit(1)

            Text("Total recorded")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .tickCard(tint: color)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(project.name), \(TickDurationFormatter.shortString(from: duration)) total recorded, created \(project.createdAt.formatted(date: .abbreviated, time: .omitted))")
    }
}

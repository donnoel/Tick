import SwiftUI

struct ProjectsView: View {
    let viewModel: TickViewModel
    @State private var isAddingProject = false
    @State private var deletionMessage: String?
    @State private var projectActionMessage: String?

    var body: some View {
        NavigationStack {
            List {
                if viewModel.activeProjects.isEmpty {
                    ContentUnavailableView(
                        "No Spaces",
                        systemImage: "folder.badge.plus",
                        description: Text("Add a space before starting Tick.")
                    )
                } else {
                    Section("Active Spaces") {
                        ForEach(viewModel.activeProjects) { project in
                            NavigationLink {
                                ProjectDetailView(viewModel: viewModel, project: project)
                            } label: {
                                ProjectRowView(
                                    project: project,
                                    projects: viewModel.activeProjects,
                                    duration: viewModel.totalDuration(for: project.id)
                                )
                            }
                            .accessibilityHint("Opens space details.")
                            .swipeActions(edge: .leading, allowsFullSwipe: false) {
                                Button("Archive") {
                                    archiveProject(project.id)
                                }
                                .tint(.orange)
                                .accessibilityLabel("Archive space")
                                .accessibilityHint("Moves this space to Archived Spaces without deleting it.")
                            }
                        }
                        .onDelete { indexSet in
                            deleteProjects(at: indexSet, from: viewModel.activeProjects)
                        }
                    }
                }

                let archivedProjects = archivedProjects
                if !archivedProjects.isEmpty {
                    Section("Archived Spaces") {
                        ForEach(archivedProjects) { project in
                            NavigationLink {
                                ProjectDetailView(viewModel: viewModel, project: project)
                            } label: {
                                ProjectRowView(
                                    project: project,
                                    projects: viewModel.projects,
                                    duration: viewModel.totalDuration(for: project.id),
                                    showsArchivedBadge: true
                                )
                            }
                            .accessibilityHint("Opens space details.")
                            .swipeActions(edge: .leading, allowsFullSwipe: false) {
                                Button("Restore") {
                                    restoreProject(project.id)
                                }
                                .tint(.green)
                                .accessibilityLabel("Restore space")
                                .accessibilityHint("Moves this space back to Active Spaces.")
                            }
                        }
                        .onDelete { indexSet in
                            deleteProjects(at: indexSet, from: archivedProjects)
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(TickPalette.appBackground)
            .navigationTitle("Spaces")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        isAddingProject = true
                    } label: {
                        Label("Add Space", systemImage: "plus")
                    }
                    .accessibilityIdentifier("projects.addProjectButton")
                    .accessibilityHint("Create a new space for Tick sessions.")
                }
            }
            .sheet(isPresented: $isAddingProject) {
                AddProjectView(viewModel: viewModel)
            }
            .alert("Could Not Delete", isPresented: deletionAlertIsPresented) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(deletionMessage ?? "Tick could not delete that space.")
            }
            .alert("Could Not Update Space", isPresented: projectActionAlertIsPresented) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(projectActionMessage ?? "Tick could not update that space.")
            }
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

    private var archivedProjects: [TickProject] {
        viewModel.projects
            .filter(\.isArchived)
            .sorted { $0.createdAt < $1.createdAt }
    }

    private func deleteProjects(at indexSet: IndexSet, from projects: [TickProject]) {
        Task {
            for index in indexSet {
                let didDelete = await viewModel.deleteProject(id: projects[index].id)
                if !didDelete {
                    deletionMessage = viewModel.errorMessage ?? "Tick could not delete that space."
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

private struct ProjectRowView: View {
    let project: TickProject
    let projects: [TickProject]
    let duration: TimeInterval
    var showsArchivedBadge = false

    var body: some View {
        HStack(spacing: 12) {
            TickProjectBadge(color: TickProjectAccent.color(for: project, in: projects), systemImage: "folder.fill")

            VStack(alignment: .leading, spacing: 4) {
                Text(project.name)
                    .font(.headline)

                Text("Created \(project.createdAt.formatted(date: .abbreviated, time: .omitted))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if showsArchivedBadge {
                    Text("Archived")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .accessibilityLabel("Archived space")
                }
            }

            Spacer()

            Text(TickDurationFormatter.shortString(from: duration))
                .font(.body.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        let base = "\(project.name), \(TickDurationFormatter.shortString(from: duration)) recorded"
        return showsArchivedBadge ? "\(base), archived" : base
    }
}

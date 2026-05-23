import SwiftUI

struct ProjectsView: View {
    let viewModel: TickViewModel
    @State private var isAddingProject = false
    @State private var deletionMessage: String?

    var body: some View {
        NavigationStack {
            List {
                if viewModel.activeProjects.isEmpty {
                    ContentUnavailableView(
                        "No Projects",
                        systemImage: "folder.badge.plus",
                        description: Text("Add a project before starting Tick.")
                    )
                } else {
                    Section("Active Projects") {
                        ForEach(viewModel.activeProjects) { project in
                            NavigationLink {
                                ProjectDetailView(viewModel: viewModel, project: project)
                            } label: {
                                ProjectRowView(
                                    project: project,
                                    duration: viewModel.totalDuration(for: project.id)
                                )
                            }
                            .accessibilityHint("Opens project details.")
                        }
                        .onDelete { indexSet in
                            deleteProjects(at: indexSet, from: viewModel.activeProjects)
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(TickPalette.appBackground)
            .navigationTitle("Projects")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        isAddingProject = true
                    } label: {
                        Label("Add Project", systemImage: "plus")
                    }
                    .accessibilityHint("Create a new project for Tick sessions.")
                }
            }
            .sheet(isPresented: $isAddingProject) {
                AddProjectView(viewModel: viewModel)
            }
            .alert("Could Not Delete", isPresented: deletionAlertIsPresented) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(deletionMessage ?? "Tick could not delete that project.")
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

    private func deleteProjects(at indexSet: IndexSet, from projects: [TickProject]) {
        Task {
            for index in indexSet {
                let didDelete = await viewModel.deleteProject(id: projects[index].id)
                if !didDelete {
                    deletionMessage = viewModel.errorMessage ?? "Tick could not delete that project."
                    return
                }
            }
        }
    }
}

private struct ProjectRowView: View {
    let project: TickProject
    let duration: TimeInterval

    var body: some View {
        HStack(spacing: 12) {
            TickProjectBadge(color: TickProjectAccent.color(for: project.id), systemImage: "folder.fill")

            VStack(alignment: .leading, spacing: 4) {
                Text(project.name)
                    .font(.headline)

                Text("Created \(project.createdAt.formatted(date: .abbreviated, time: .omitted))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(TickDurationFormatter.shortString(from: duration))
                .font(.body.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(project.name), \(TickDurationFormatter.shortString(from: duration)) tracked")
    }
}

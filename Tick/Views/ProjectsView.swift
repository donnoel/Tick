import SwiftUI

struct ProjectsView: View {
    let viewModel: TickViewModel
    @State private var isAddingProject = false

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
                            ProjectRowView(
                                project: project,
                                duration: viewModel.totalDuration(for: project.id)
                            )
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

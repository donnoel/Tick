import SwiftUI

struct ProjectsView: View {
    let viewModel: TickViewModel
    @AppStorage("spacesSortMode") private var spacesSortMode = ProjectSortMode.mostActive.rawValue
    @State private var isAddingProject = false
    @State private var deletionMessage: String?
    @State private var projectActionMessage: String?

    var body: some View {
        NavigationStack {
            List {
                let projectIDs = viewModel.projects.map(\.id)
                let orderedActiveProjects = activeProjects

                Section {
                    HStack {
                        ProjectSortModePicker(selection: $spacesSortMode)
                            .frame(maxWidth: 360)

                        Spacer(minLength: 0)
                    }
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 8, trailing: 16))

                if orderedActiveProjects.isEmpty {
                    ContentUnavailableView(
                        "No Spaces",
                        systemImage: "folder.badge.plus",
                        description: Text("Add a space before starting Tick.")
                    )
                } else {
                    Section("Active Spaces") {
                        ForEach(orderedActiveProjects) { project in
                            activeProjectRow(project, projectIDs: projectIDs)
                        }
                        .onDelete { indexSet in
                            deleteProjects(at: indexSet, from: orderedActiveProjects)
                        }
                        .onMove { source, destination in
                            guard selectedSortMode == .manual else {
                                return
                            }

                            moveActiveProjects(from: source, to: destination)
                        }
                        .moveDisabled(selectedSortMode != .manual)
                    }
                }

                let archivedProjects = archivedProjects
                if !archivedProjects.isEmpty {
                    Section("Archived Spaces") {
                        ForEach(archivedProjects) { project in
                            archivedProjectRow(project, projectIDs: projectIDs)
                        }
                        .onDelete { indexSet in
                            deleteProjects(at: indexSet, from: archivedProjects)
                        }
                        .onMove { source, destination in
                            guard selectedSortMode == .manual else {
                                return
                            }

                            moveArchivedProjects(from: source, to: destination)
                        }
                        .moveDisabled(selectedSortMode != .manual)
                    }
                }

                if !viewModel.projects.isEmpty {
                    Section {
                        TotalSpacesFooter(totalDuration: totalSpacesDuration)
                    }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 14, leading: 16, bottom: 28, trailing: 16))
                }
            }
            .scrollContentBackground(.hidden)
            .background(TickPalette.appBackground)
            .navigationTitle("Spaces")
            .toolbar {
                if canReorderProjects && selectedSortMode == .manual {
                    ToolbarItem(placement: .topBarLeading) {
                        EditButton()
                            .accessibilityHint("Shows controls for reordering and deleting spaces.")
                    }
                }

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

    private var selectedSortMode: ProjectSortMode {
        ProjectSortMode(rawValue: spacesSortMode) ?? .mostActive
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
        TickProject.sortedByDisplayOrder(viewModel.projects.filter(\.isArchived))
    }

    private var activeProjects: [TickProject] {
        let projects = viewModel.activeProjects

        switch selectedSortMode {
        case .mostActive:
            return TickProject.sortedByActivity(
                projects,
                durationsByProjectID: durationsByProjectID(for: projects)
            )
        case .manual:
            return projects
        }
    }

    private var canReorderProjects: Bool {
        activeProjects.count > 1 || archivedProjects.count > 1
    }

    private var totalSpacesDuration: TimeInterval {
        viewModel.projects.reduce(0) { total, project in
            total + viewModel.totalDuration(for: project.id)
        }
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

    private func moveActiveProjects(from source: IndexSet, to destination: Int) {
        Task {
            let didMove = await viewModel.moveActiveProjects(from: source, to: destination)
            if !didMove {
                projectActionMessage = viewModel.errorMessage ?? "Tick could not reorder those spaces."
            }
        }
    }

    private func moveArchivedProjects(from source: IndexSet, to destination: Int) {
        Task {
            let didMove = await viewModel.moveArchivedProjects(from: source, to: destination)
            if !didMove {
                projectActionMessage = viewModel.errorMessage ?? "Tick could not reorder those spaces."
            }
        }
    }

    private func durationsByProjectID(for projects: [TickProject]) -> [TickProject.ID: TimeInterval] {
        Dictionary(uniqueKeysWithValues: projects.map { project in
            (project.id, viewModel.totalDuration(for: project.id))
        })
    }

    private func activeProjectRow(_ project: TickProject, projectIDs: [TickProject.ID]) -> some View {
        NavigationLink {
            ProjectDetailView(viewModel: viewModel, project: project)
        } label: {
            ProjectRowView(
                project: project,
                duration: viewModel.totalDuration(for: project.id),
                color: TickProjectAccent.color(for: project.id, among: projectIDs)
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

    private func archivedProjectRow(_ project: TickProject, projectIDs: [TickProject.ID]) -> some View {
        NavigationLink {
            ProjectDetailView(viewModel: viewModel, project: project)
        } label: {
            ProjectRowView(
                project: project,
                duration: viewModel.totalDuration(for: project.id),
                color: TickProjectAccent.color(for: project.id, among: projectIDs),
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
}

private struct ProjectSortModePicker: View {
    @Binding var selection: String

    var body: some View {
        Picker("Order", selection: $selection) {
            Text(ProjectSortMode.mostActive.title)
                .tag(ProjectSortMode.mostActive.rawValue)
            Text(ProjectSortMode.manual.title)
                .tag(ProjectSortMode.manual.rawValue)
        }
        .pickerStyle(.segmented)
        .accessibilityHint("Chooses how active spaces are ordered.")
    }
}

private enum ProjectSortMode: String, CaseIterable {
    case mostActive
    case manual

    var title: String {
        switch self {
        case .mostActive:
            return "Most Active"
        case .manual:
            return "Manual"
        }
    }
}

private struct ProjectRowView: View {
    let project: TickProject
    let duration: TimeInterval
    let color: Color
    var showsArchivedBadge = false

    var body: some View {
        HStack(spacing: 12) {
            TickProjectBadge(color: color, systemImage: "folder.fill")

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

private struct TotalSpacesFooter: View {
    let totalDuration: TimeInterval

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            TickProjectBadge(color: TickPalette.primaryAction, systemImage: "sum")

            VStack(alignment: .leading, spacing: 4) {
                Text("Total Spaces")
                    .font(.headline)

                Text("All recorded time")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(TickDurationFormatter.shortString(from: totalDuration))
                .font(.title3.weight(.semibold).monospacedDigit())
                .foregroundStyle(TickPalette.primaryAction)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .tickCard(tint: TickPalette.primaryAction, isHighlighted: true)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Total Spaces, all recorded time, \(TickDurationFormatter.shortString(from: totalDuration))")
    }
}

import SwiftUI

struct ProjectsView: View {
    let viewModel: TickViewModel
    @AppStorage("spacesSortMode") private var spacesSortMode = ProjectSortMode.mostActive.rawValue
    @State private var isAddingProject = false
    @State private var deletionMessage: String?
    @State private var projectsPendingDeletion: [TickProject] = []
    @State private var projectActionMessage: String?
    @State private var projectBeingRenamed: TickProject?
    @State private var projectRenameName = ""

    var body: some View {
        NavigationStack {
            let projectIDs = viewModel.projects.map(\.id)
            let durationsByProjectID = durationsByProjectID()
            let orderedActiveProjects = activeProjects(durationsByProjectID: durationsByProjectID)
            let archivedProjects = archivedProjects

            List {
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
                            activeProjectRow(
                                project,
                                duration: durationsByProjectID[project.id, default: 0],
                                projectIDs: projectIDs
                            )
                        }
                        .onDelete { indexSet in
                            requestDeleteProjects(at: indexSet, from: orderedActiveProjects)
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

                if !archivedProjects.isEmpty {
                    Section("Archived Spaces") {
                        ForEach(archivedProjects) { project in
                            archivedProjectRow(
                                project,
                                duration: durationsByProjectID[project.id, default: 0],
                                projectIDs: projectIDs
                            )
                        }
                        .onDelete { indexSet in
                            requestDeleteProjects(at: indexSet, from: archivedProjects)
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
                        TotalSpacesFooter(totalDuration: totalSpacesDuration(durationsByProjectID: durationsByProjectID))
                    }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 14, leading: 16, bottom: 28, trailing: 16))
                }
            }
            .scrollContentBackground(.hidden)
            .background(TickPalette.appBackground)
            .navigationTitle("Spaces")
            .toolbar {
                if canReorderProjects(activeProjects: orderedActiveProjects, archivedProjects: archivedProjects) && selectedSortMode == .manual {
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
            .confirmationDialog(
                projectDeletionConfirmationTitle,
                isPresented: projectDeletionConfirmationIsPresented,
                titleVisibility: .visible
            ) {
                Button(projectDeletionConfirmationButtonTitle, role: .destructive) {
                    deletePendingProjects()
                }

                Button("Cancel", role: .cancel) {}
            } message: {
                Text(projectDeletionConfirmationMessage)
            }
            .alert("Could Not Update Space", isPresented: projectActionAlertIsPresented) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(projectActionMessage ?? "Tick could not update that space.")
            }
            .alert("Rename Space", isPresented: projectRenameAlertIsPresented) {
                TextField("Name", text: $projectRenameName)
                    .textInputAutocapitalization(.words)

                Button("Cancel", role: .cancel) {
                    clearProjectRenameState()
                }

                Button("Save") {
                    renameProject()
                }
                .disabled(projectRenameName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            } message: {
                Text("Give this space a short name.")
            }
        }
    }

    private var projectDeletionConfirmationIsPresented: Binding<Bool> {
        Binding {
            !projectsPendingDeletion.isEmpty
        } set: { isPresented in
            if !isPresented {
                projectsPendingDeletion = []
            }
        }
    }

    private var projectDeletionConfirmationTitle: String {
        if let project = projectsPendingDeletion.first, projectsPendingDeletion.count == 1 {
            return "Delete \(project.name)?"
        }

        return "Delete \(projectsPendingDeletion.count) Spaces?"
    }

    private var projectDeletionConfirmationButtonTitle: String {
        projectsPendingDeletion.count == 1 ? "Delete Space" : "Delete Spaces"
    }

    private var projectDeletionConfirmationMessage: String {
        if projectsPendingDeletion.count == 1 {
            return "This permanently deletes the space, its sessions, Auto Tick rules, and voice memos. This cannot be undone."
        }

        return "This permanently deletes these spaces, their sessions, Auto Tick rules, and voice memos. This cannot be undone."
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

    private var projectRenameAlertIsPresented: Binding<Bool> {
        Binding {
            projectBeingRenamed != nil
        } set: { isPresented in
            if !isPresented {
                clearProjectRenameState()
            }
        }
    }

    private var archivedProjects: [TickProject] {
        TickProject.sortedByDisplayOrder(viewModel.projects.filter(\.isArchived))
    }

    private func activeProjects(durationsByProjectID: [TickProject.ID: TimeInterval]) -> [TickProject] {
        let projects = viewModel.activeProjects

        switch selectedSortMode {
        case .mostActive:
            return TickProject.sortedByActivity(
                projects,
                durationsByProjectID: durationsByProjectID
            )
        case .manual:
            return projects
        }
    }

    private func canReorderProjects(activeProjects: [TickProject], archivedProjects: [TickProject]) -> Bool {
        activeProjects.count > 1 || archivedProjects.count > 1
    }

    private func totalSpacesDuration(durationsByProjectID: [TickProject.ID: TimeInterval]) -> TimeInterval {
        durationsByProjectID.values.reduce(0, +)
    }

    private func requestDeleteProjects(at indexSet: IndexSet, from projects: [TickProject]) {
        projectsPendingDeletion = indexSet.compactMap { index in
            guard projects.indices.contains(index) else {
                return nil
            }

            return projects[index]
        }
    }

    private func requestDeleteProject(_ project: TickProject) {
        projectsPendingDeletion = [project]
    }

    private func deletePendingProjects() {
        let projectsToDelete = projectsPendingDeletion
        projectsPendingDeletion = []

        Task {
            for project in projectsToDelete {
                let didDelete = await viewModel.deleteProject(id: project.id)
                if !didDelete {
                    deletionMessage = viewModel.errorMessage ?? "Tick could not delete that space."
                    return
                }
            }
        }
    }

    private func beginRenamingProject(_ project: TickProject) {
        projectBeingRenamed = project
        projectRenameName = project.name
    }

    private func renameProject() {
        guard let projectBeingRenamed else {
            return
        }
        let name = projectRenameName
        clearProjectRenameState()

        Task {
            let didRename = await viewModel.updateProjectName(
                id: projectBeingRenamed.id,
                name: name
            )

            if !didRename {
                projectActionMessage = viewModel.errorMessage ?? "Tick could not rename that space."
            }
        }
    }

    private func clearProjectRenameState() {
        projectBeingRenamed = nil
        projectRenameName = ""
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

    private func durationsByProjectID() -> [TickProject.ID: TimeInterval] {
        viewModel.sessions.reduce(into: [:]) { durationsByProjectID, session in
            durationsByProjectID[session.projectID, default: 0] += session.duration()
        }
    }

    private func activeProjectRow(
        _ project: TickProject,
        duration: TimeInterval,
        projectIDs: [TickProject.ID]
    ) -> some View {
        NavigationLink {
            ProjectDetailView(viewModel: viewModel, project: project)
        } label: {
            ProjectRowView(
                project: project,
                duration: duration,
                color: TickProjectAccent.color(for: project.id, among: projectIDs)
            )
        }
        .accessibilityHint("Opens space details.")
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                requestDeleteProject(project)
            } label: {
                Label("Delete", systemImage: "trash")
            }
            .accessibilityLabel("Delete space")
            .accessibilityHint("Shows a confirmation before permanently deleting this space.")

            Button {
                beginRenamingProject(project)
            } label: {
                Label("Rename", systemImage: "pencil")
            }
            .tint(.blue)
            .accessibilityLabel("Rename space")
            .accessibilityHint("Opens a rename field for this space.")
        }
        .swipeActions(edge: .leading, allowsFullSwipe: false) {
            Button("Archive") {
                archiveProject(project.id)
            }
            .tint(.orange)
            .accessibilityLabel("Archive space")
            .accessibilityHint("Moves this space to Archived Spaces without deleting it.")
        }
    }

    private func archivedProjectRow(
        _ project: TickProject,
        duration: TimeInterval,
        projectIDs: [TickProject.ID]
    ) -> some View {
        NavigationLink {
            ProjectDetailView(viewModel: viewModel, project: project)
        } label: {
            ProjectRowView(
                project: project,
                duration: duration,
                color: TickProjectAccent.color(for: project.id, among: projectIDs),
                showsArchivedBadge: true
            )
        }
        .accessibilityHint("Opens space details.")
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                requestDeleteProject(project)
            } label: {
                Label("Delete", systemImage: "trash")
            }
            .accessibilityLabel("Delete space")
            .accessibilityHint("Shows a confirmation before permanently deleting this space.")

            Button {
                beginRenamingProject(project)
            } label: {
                Label("Rename", systemImage: "pencil")
            }
            .tint(.blue)
            .accessibilityLabel("Rename space")
            .accessibilityHint("Opens a rename field for this space.")
        }
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

import SwiftUI

struct SessionDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let viewModel: TickViewModel
    let sessionID: TimeSession.ID
    @State private var title: String
    @State private var notes: String
    @State private var projectID: TickProject.ID?

    @MainActor
    init(viewModel: TickViewModel, session: TimeSession) {
        self.viewModel = viewModel
        self.sessionID = session.id
        _title = State(initialValue: session.title)
        _notes = State(initialValue: session.notes)
        _projectID = State(initialValue: session.projectID)
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { timeline in
            if let session = viewModel.session(for: sessionID) {
                form(for: session, displayDate: timeline.date)
            } else {
                ContentUnavailableView(
                    "Session Missing",
                    systemImage: "clock.badge.exclamationmark",
                    description: Text("Tick could not find this session.")
                )
                .navigationTitle("Session")
            }
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    Task {
                        guard let projectID else {
                            return
                        }

                        let didUpdate = await viewModel.updateSession(
                            id: sessionID,
                            title: title,
                            notes: notes,
                            projectID: projectID
                        )

                        if didUpdate {
                            dismiss()
                        }
                    }
                }
                .disabled(projectID == nil)
            }
        }
    }

    private func form(for session: TimeSession, displayDate: Date) -> some View {
        Form {
            Section("Details") {
                if projectOptions(for: session).isEmpty {
                    LabeledContent("Project", value: projectName(for: session.projectID))
                } else {
                    Picker("Project", selection: $projectID) {
                        ForEach(projectOptions(for: session)) { project in
                            Text(project.name).tag(Optional(project.id))
                        }
                    }
                    .accessibilityHint("Choose the project for this session.")
                }

                TextField("Title", text: $title)
                    .textInputAutocapitalization(.sentences)
                    .accessibilityLabel("Title")
                    .accessibilityHint("Edit the short title for this session.")

                TextField("Notes", text: $notes, axis: .vertical)
                    .lineLimit(3...8)
                    .textInputAutocapitalization(.sentences)
                    .accessibilityLabel("Notes")
                    .accessibilityHint("Edit notes for this session.")
            }

            Section("Timing") {
                LabeledContent("Date", value: session.referenceDate.formatted(date: .abbreviated, time: .omitted))

                if let startedAt = session.startedAt {
                    LabeledContent("Start", value: startedAt.formatted(date: .omitted, time: .shortened))
                }

                if let endedAt = session.endedAt {
                    LabeledContent("End", value: endedAt.formatted(date: .omitted, time: .shortened))
                }

                LabeledContent("Duration", value: TickDurationFormatter.shortString(from: session.duration(at: displayDate)))
                    .accessibilityValue(TickDurationFormatter.shortString(from: session.duration(at: displayDate)))

                LabeledContent("Entry Source", value: sourceDescription(for: session.entrySource))
            }
        }
        .navigationTitle("Session")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func projectOptions(for session: TimeSession) -> [TickProject] {
        var options = viewModel.activeProjects

        if let currentProject = viewModel.project(for: session.projectID),
           !options.contains(where: { $0.id == currentProject.id }) {
            options.append(currentProject)
        }

        return options.sorted { $0.createdAt < $1.createdAt }
    }

    private func projectName(for projectID: TickProject.ID) -> String {
        viewModel.project(for: projectID)?.name ?? "Unknown Project"
    }

    private func sourceDescription(for source: SessionEntrySource) -> String {
        switch source {
        case .timer:
            "Timer"
        case .manual:
            "Manual"
        case .autoLocation:
            "Auto Tick"
        }
    }
}

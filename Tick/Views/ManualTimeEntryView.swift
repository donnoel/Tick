import SwiftUI

struct ManualTimeEntryView: View {
    @Environment(\.dismiss) private var dismiss
    let viewModel: TickViewModel
    @State private var projectID: TickProject.ID?
    @State private var title = ""
    @State private var notes = ""
    @State private var date = Date()
    @State private var hours = 0
    @State private var minutes = 30

    @MainActor
    init(viewModel: TickViewModel) {
        self.viewModel = viewModel
        _projectID = State(initialValue: viewModel.selectedProjectID ?? viewModel.activeProjects.first?.id)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Project") {
                    Picker("Project", selection: $projectID) {
                        ForEach(viewModel.activeProjects) { project in
                            Text(project.name).tag(Optional(project.id))
                        }
                    }
                    .accessibilityHint("Choose the project for this manual time.")
                }

                Section("Details") {
                    TextField("Title", text: $title)
                        .textInputAutocapitalization(.sentences)

                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                        .textInputAutocapitalization(.sentences)
                }

                Section("Time") {
                    DatePicker("Date", selection: $date, displayedComponents: [.date, .hourAndMinute])

                    Stepper(value: $hours, in: 0...24) {
                        Text("Hours: \(hours)")
                    }

                    Stepper(value: $minutes, in: 0...55, step: 5) {
                        Text("Minutes: \(minutes)")
                    }
                }
            }
            .navigationTitle("Add Time")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            let didAdd = await viewModel.addManualSession(
                                projectID: projectID,
                                title: title,
                                notes: notes,
                                date: date,
                                duration: duration
                            )

                            if didAdd {
                                dismiss()
                            }
                        }
                    }
                    .disabled(projectID == nil || duration <= 0)
                }
            }
        }
    }

    private var duration: TimeInterval {
        TimeInterval((hours * 60 + minutes) * 60)
    }
}

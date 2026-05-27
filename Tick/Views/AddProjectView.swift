import SwiftUI

struct AddProjectView: View {
    @Environment(\.dismiss) private var dismiss
    let viewModel: TickViewModel
    @State private var projectName = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Space") {
                    TextField("Name", text: $projectName)
                        .textInputAutocapitalization(.words)
                        .submitLabel(.done)
                        .accessibilityIdentifier("addProject.nameField")
                        .accessibilityHint("Enter a short space name.")
                }
            }
            .navigationTitle("New Space")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        Task {
                            let didAdd = await viewModel.addProject(name: projectName)

                            if didAdd {
                                dismiss()
                            }
                        }
                    }
                    .disabled(projectName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityIdentifier("addProject.saveButton")
                }
            }
        }
    }
}

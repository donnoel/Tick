import SwiftUI

struct AutoTickRuleDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let viewModel: TickViewModel
    let ruleID: AutoTickRule.ID
    @State private var projectID: TickProject.ID?
    @State private var name: String
    @State private var radiusMeters: Double
    @State private var startsOnArrival: Bool
    @State private var stopsOnDeparture: Bool
    @State private var isEnabled: Bool
    @State private var isConfirmingDelete = false

    @MainActor
    init(viewModel: TickViewModel, rule: AutoTickRule) {
        self.viewModel = viewModel
        self.ruleID = rule.id
        _projectID = State(initialValue: rule.projectID)
        _name = State(initialValue: rule.name)
        _radiusMeters = State(initialValue: rule.radiusMeters)
        _startsOnArrival = State(initialValue: rule.startsOnArrival)
        _stopsOnDeparture = State(initialValue: rule.stopsOnDeparture)
        _isEnabled = State(initialValue: rule.isEnabled)
    }

    var body: some View {
        if let rule = viewModel.autoTickRule(for: ruleID) {
            form(for: rule)
        } else {
            ContentUnavailableView(
                "Auto Tick Missing",
                systemImage: "location.slash",
                description: Text("Tick could not find this Auto Tick rule.")
            )
            .navigationTitle("Auto Tick")
        }
    }

    private func form(for rule: AutoTickRule) -> some View {
        Form {
            Section("Details") {
                TextField("Rule Name", text: $name)
                    .textInputAutocapitalization(.words)
                    .accessibilityLabel("Rule name")
                    .accessibilityHint("Edit the name for this Auto Tick rule.")

                Picker("Project", selection: $projectID) {
                    ForEach(projectOptions(for: rule)) { project in
                        Text(project.name).tag(Optional(project.id))
                    }
                }
                .accessibilityHint("Choose the project for automatically tracked time.")
            }

            Section("Location") {
                LabeledContent("Latitude", value: rule.latitude.formatted(.number.precision(.fractionLength(5))))
                LabeledContent("Longitude", value: rule.longitude.formatted(.number.precision(.fractionLength(5))))
                Text("Coordinates stay fixed in this version. Create a new rule to use a different place.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Automation") {
                Picker("Radius", selection: $radiusMeters) {
                    ForEach(radiusOptions, id: \.self) { radius in
                        Text("\(Int(radius)) meters").tag(radius)
                    }
                }
                .accessibilityLabel("Radius")
                .accessibilityValue("\(Int(radiusMeters)) meters")
                .accessibilityHint("Adjusts the Auto Tick geofence radius.")

                Toggle("Enabled", isOn: $isEnabled)
                    .accessibilityHint("Turns this Auto Tick rule on or off.")
                Toggle("Start on Arrival", isOn: $startsOnArrival)
                    .accessibilityHint("Starts a Tick when you arrive at this location.")
                Toggle("Stop on Departure", isOn: $stopsOnDeparture)
                    .accessibilityHint("Stops the matching Auto Tick when you leave this location.")

                if !startsOnArrival && !stopsOnDeparture {
                    Text("Choose arrival, departure, or both before saving.")
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .accessibilityLabel("Auto Tick validation")
                }
            }

            if let errorMessage = viewModel.errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                        .accessibilityLabel("Save error")
                }
            }

            Section {
                Button("Delete Auto Tick", role: .destructive) {
                    isConfirmingDelete = true
                }
                .accessibilityHint("Shows a confirmation before deleting this Auto Tick rule.")
            }
        }
        .navigationTitle("Auto Tick")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    Task {
                        let didUpdate = await viewModel.updateAutoTickRule(
                            id: ruleID,
                            projectID: projectID,
                            name: name,
                            radiusMeters: radiusMeters,
                            startsOnArrival: startsOnArrival,
                            stopsOnDeparture: stopsOnDeparture,
                            isEnabled: isEnabled
                        )

                        if didUpdate {
                            dismiss()
                        }
                    }
                }
                .disabled(!canSave)
            }
        }
        .confirmationDialog(
            "Delete Auto Tick?",
            isPresented: $isConfirmingDelete,
            titleVisibility: .visible
        ) {
            Button("Delete Auto Tick", role: .destructive) {
                Task {
                    let didDelete = await viewModel.deleteAutoTickRule(id: ruleID)

                    if didDelete {
                        dismiss()
                    }
                }
            }

            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes the saved location rule and stops monitoring that geofence.")
        }
    }

    private var canSave: Bool {
        projectID != nil &&
            !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            radiusMeters > 0 &&
            (startsOnArrival || stopsOnDeparture)
    }

    private func projectOptions(for rule: AutoTickRule) -> [TickProject] {
        var options = viewModel.activeProjects

        if let currentProject = viewModel.project(for: rule.projectID),
           !options.contains(where: { $0.id == currentProject.id }) {
            options.append(currentProject)
        }

        return options.sorted { $0.createdAt < $1.createdAt }
    }

    private var radiusOptions: [Double] {
        let options = AutoTickRule.radiusOptionMeters + [radiusMeters]
        return Array(Set(options)).sorted()
    }
}

import SwiftUI

struct AddAutoTickRuleView: View {
    @Environment(\.dismiss) private var dismiss
    let viewModel: TickViewModel
    @State private var projectID: TickProject.ID?
    @State private var name = ""
    @State private var coordinate: AutoTickCoordinate?
    @State private var radiusMeters = 150.0
    @State private var startsOnArrival = true
    @State private var stopsOnDeparture = true
    @State private var isEnabled = true

    @MainActor
    init(viewModel: TickViewModel) {
        self.viewModel = viewModel
        _projectID = State(initialValue: viewModel.selectedProjectID ?? viewModel.activeProjects.first?.id)
        _coordinate = State(initialValue: viewModel.latestAutoTickCoordinate)
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
                    .accessibilityHint("Choose the project for automatically tracked time.")
                }

                Section("Location") {
                    TextField("Location Name", text: $name)
                        .textInputAutocapitalization(.words)
                        .accessibilityHint("Name this Auto Tick location.")

                    Button {
                        viewModel.requestCurrentAutoTickLocation()
                    } label: {
                        Label("Use Current Location", systemImage: "location")
                    }
                    .accessibilityHint("Gets the current location for this rule.")

                    if let coordinate {
                        LabeledContent("Latitude", value: coordinate.latitude.formatted(.number.precision(.fractionLength(5))))
                        LabeledContent("Longitude", value: coordinate.longitude.formatted(.number.precision(.fractionLength(5))))
                    } else {
                        Text(viewModel.autoTickLocationMessage)
                            .foregroundStyle(.secondary)
                    }

                    if let errorMessage = viewModel.autoTickLocationErrorMessage {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }

                Section("Automation") {
                    Stepper(value: $radiusMeters, in: 50...1_000, step: 25) {
                        Text("Radius: \(Int(radiusMeters)) meters")
                    }
                    .accessibilityValue("\(Int(radiusMeters)) meters")

                    Toggle("Enabled", isOn: $isEnabled)
                    Toggle("Start on Arrival", isOn: $startsOnArrival)
                    Toggle("Stop on Departure", isOn: $stopsOnDeparture)
                }
            }
            .navigationTitle("New Auto Tick")
            .onChange(of: viewModel.latestAutoTickCoordinate) { _, newCoordinate in
                coordinate = newCoordinate
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
                            let didAdd = await viewModel.addAutoTickRule(
                                projectID: projectID,
                                name: name,
                                latitude: coordinate?.latitude,
                                longitude: coordinate?.longitude,
                                radiusMeters: radiusMeters,
                                startsOnArrival: startsOnArrival,
                                stopsOnDeparture: stopsOnDeparture,
                                isEnabled: isEnabled
                            )

                            if didAdd {
                                dismiss()
                            }
                        }
                    }
                    .disabled(!canSave)
                }
            }
        }
    }

    private var canSave: Bool {
        projectID != nil &&
            coordinate != nil &&
            !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            (startsOnArrival || stopsOnDeparture)
    }
}

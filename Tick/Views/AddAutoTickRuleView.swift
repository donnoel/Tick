import SwiftUI

struct AddAutoTickRuleView: View {
    @Environment(\.dismiss) private var dismiss
    let viewModel: TickViewModel
    @State private var projectID: TickProject.ID?
    @State private var name = ""
    @State private var coordinate: AutoTickCoordinate?
    @State private var radiusMeters = 50.0
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
                Section("Space") {
                    Picker("Space", selection: $projectID) {
                        ForEach(viewModel.activeProjects) { project in
                            Text(project.name).tag(Optional(project.id))
                        }
                    }
                    .accessibilityHint("Choose the space for automatic time.")
                }

                Section("Location") {
                    Text(locationGuidance)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .accessibilityLabel("Location guidance")

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
                    Picker("Radius", selection: $radiusMeters) {
                        ForEach(radiusOptions, id: \.self) { radius in
                            Text("\(Int(radius)) meters").tag(radius)
                        }
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

    private var locationGuidance: String {
        switch viewModel.autoTickLocationAuthorizationStatus {
        case .notDetermined:
            "Use Current Location will ask for permission. After granting access, tap it again to capture this rule."
        case .authorizedWhenInUse:
            "Tick can capture this location while the app is open. Background arrival and departure work best with Always access."
        case .authorizedAlways:
            "Tick can capture this location and monitor enabled rules in the background."
        case .denied:
            "Location access is denied. You can keep using Tick, but current location capture needs permission in Settings."
        case .restricted:
            "Location access is restricted on this device. You can keep using Tick without Auto Ticks."
        case .unknown:
            "Tick cannot read the current location permission state."
        }
    }

    private var radiusOptions: [Double] {
        let options = AutoTickRule.radiusOptionMeters + [radiusMeters]
        return Array(Set(options)).sorted()
    }
}

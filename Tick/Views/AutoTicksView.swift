import SwiftUI

struct AutoTicksView: View {
    let viewModel: TickViewModel
    @State private var isAddingRule = false

    var body: some View {
        NavigationStack {
            List {
                permissionSection
                rulesSection
            }
            .scrollContentBackground(.hidden)
            .background(TickPalette.appBackground)
            .navigationTitle("Auto Ticks")
            .navigationDestination(for: AutoTickRule.ID.self) { ruleID in
                if let rule = viewModel.autoTickRule(for: ruleID) {
                    AutoTickRuleDetailView(viewModel: viewModel, rule: rule)
                } else {
                    ContentUnavailableView(
                        "Auto Tick Missing",
                        systemImage: "location.slash",
                        description: Text("Tick could not find this Auto Tick rule.")
                    )
                    .navigationTitle("Auto Tick")
                }
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        isAddingRule = true
                    } label: {
                        Label("Add Auto Tick", systemImage: "plus")
                    }
                    .disabled(viewModel.activeProjects.isEmpty)
                    .accessibilityHint("Create a location rule for automatic time tracking.")
                }
            }
            .sheet(isPresented: $isAddingRule) {
                AddAutoTickRuleView(viewModel: viewModel)
            }
        }
    }

    private var permissionSection: some View {
        Section {
            LocationStatusCard(
                status: viewModel.autoTickLocationAuthorizationStatus,
                errorMessage: viewModel.autoTickLocationErrorMessage,
                requestLocation: viewModel.requestAutoTickLocationPermission,
                requestBackgroundLocation: viewModel.requestAutoTickBackgroundLocationPermission
            )
        }
        .listRowBackground(Color.clear)
    }

    private var rulesSection: some View {
        Section("Rules") {
            if viewModel.autoTickRules.isEmpty {
                ContentUnavailableView(
                    "No Auto Ticks yet",
                    systemImage: "location.circle",
                    description: Text("Add a place and Tick can start or stop for you.")
                )
            } else {
                ForEach(viewModel.autoTickRules) { rule in
                    HStack(spacing: 12) {
                        NavigationLink(value: rule.id) {
                            AutoTickRuleRowView(
                                rule: rule,
                                projectName: projectName(for: rule.projectID)
                            )
                        }
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(ruleAccessibilityLabel(rule, projectName: projectName(for: rule.projectID)))
                        .accessibilityValue(ruleAccessibilityValue(rule))
                        .accessibilityHint("Opens this Auto Tick rule for editing.")

                        Toggle("Enabled", isOn: Binding {
                            viewModel.autoTickRule(for: rule.id)?.isEnabled ?? rule.isEnabled
                        } set: { isEnabled in
                            Task {
                                await viewModel.setAutoTickRule(rule.id, isEnabled: isEnabled)
                            }
                        })
                        .labelsHidden()
                        .accessibilityLabel("\(rule.name) enabled")
                    }
                }
            }
        }
    }

    private func projectName(for projectID: TickProject.ID) -> String {
        viewModel.project(for: projectID)?.name ?? "Unknown Project"
    }

    private func ruleAccessibilityLabel(_ rule: AutoTickRule, projectName: String) -> String {
        "\(rule.name), \(projectName)"
    }

    private func ruleAccessibilityValue(_ rule: AutoTickRule) -> String {
        "\(rule.isEnabled ? "Enabled" : "Disabled"), \(Int(rule.radiusMeters.rounded())) meters, \(automationDescription(for: rule))"
    }

    private func automationDescription(for rule: AutoTickRule) -> String {
        switch (rule.startsOnArrival, rule.stopsOnDeparture) {
        case (true, true):
            "starts on arrival and stops on departure"
        case (true, false):
            "starts on arrival"
        case (false, true):
            "stops on departure"
        case (false, false):
            "no automation behavior"
        }
    }
}

private struct LocationStatusCard: View {
    let status: AutoTickLocationAuthorizationStatus
    let errorMessage: String?
    let requestLocation: () -> Void
    let requestBackgroundLocation: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: systemImage)
                .font(.headline)
                .foregroundStyle(tint)

            Text(bodyText)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if let errorMessage {
                Text(errorMessage)
                    .font(.subheadline)
                    .foregroundStyle(.red)
                    .accessibilityLabel("Location error")
            }

            switch status {
            case .notDetermined:
                Button("Allow Location Access") {
                    requestLocation()
                }
                .buttonStyle(.borderedProminent)
                .accessibilityHint("Requests location permission for Auto Ticks.")
            case .authorizedWhenInUse:
                Button("Allow Background Access") {
                    requestBackgroundLocation()
                }
                .buttonStyle(.borderedProminent)
                .accessibilityHint("Requests background location access for geofenced Auto Tick rules.")
            case .authorizedAlways, .denied, .restricted, .unknown:
                EmptyView()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .tickCard(tint: tint, isHighlighted: status == .authorizedAlways)
    }

    private var title: String {
        switch status {
        case .authorizedAlways:
            "Location Ready"
        case .authorizedWhenInUse:
            "Background Access Needed"
        case .notDetermined:
            "Location Off"
        case .denied, .restricted:
            "Location Disabled"
        case .unknown:
            "Location Status Unknown"
        }
    }

    private var bodyText: String {
        switch status {
        case .authorizedAlways:
            "Auto Ticks can run for places you choose."
        case .authorizedWhenInUse:
            "Allow Always access for reliable arrival and departure automation."
        case .notDetermined:
            "Allow location access to create Auto Ticks."
        case .denied, .restricted:
            "Allow location access in Settings to use Auto Ticks."
        case .unknown:
            "Tick will keep working while location access is checked."
        }
    }

    private var systemImage: String {
        switch status {
        case .authorizedAlways:
            "location.fill"
        case .authorizedWhenInUse:
            "location.circle"
        case .notDetermined:
            "location"
        case .denied, .restricted:
            "location.slash"
        case .unknown:
            "questionmark.circle"
        }
    }

    private var tint: Color {
        switch status {
        case .authorizedAlways:
            TickPalette.locationReady
        case .authorizedWhenInUse, .notDetermined:
            TickPalette.primaryAction
        case .denied, .restricted:
            .red
        case .unknown:
            .secondary
        }
    }
}

private struct AutoTickRuleRowView: View {
    let rule: AutoTickRule
    let projectName: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            TickProjectBadge(color: TickProjectAccent.color(for: rule.projectID), systemImage: "location.fill")

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(rule.name)
                            .font(.headline)

                        Text(projectName)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Text(rule.isEnabled ? "Enabled" : "Disabled")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(statusTint.opacity(0.14), in: Capsule())
                        .foregroundStyle(statusTint)
                }

                HStack(spacing: 12) {
                    Label("\(Int(rule.radiusMeters.rounded())) m", systemImage: "circle.dotted")

                    if rule.startsOnArrival {
                        Label("Arrival", systemImage: "arrow.down.to.line.compact")
                    }

                    if rule.stopsOnDeparture {
                        Label("Departure", systemImage: "arrow.up.from.line.compact")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .accessibilityElement(children: .combine)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .contain)
    }

    private var statusTint: Color {
        rule.isEnabled ? TickPalette.locationReady : .secondary
    }
}

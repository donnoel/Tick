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
        Section("Location Access") {
            Text("Auto Ticks are optional. Tick uses location only for rules you create and enable.")
                .foregroundStyle(.secondary)

            Text("Use Current Location captures a rule coordinate. Always access is needed for reliable arrival and departure automation in the background.")
                .foregroundStyle(.secondary)

            Text(viewModel.autoTickLocationAuthorizationStatus.displayText)
                .accessibilityLabel("Location permission")
                .accessibilityValue(viewModel.autoTickLocationAuthorizationStatus.displayText)

            if let errorMessage = viewModel.autoTickLocationErrorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
                    .accessibilityLabel("Location error")
            }

            switch viewModel.autoTickLocationAuthorizationStatus {
            case .notDetermined:
                Button("Allow Location Access") {
                    viewModel.requestAutoTickLocationPermission()
                }
                .accessibilityHint("Requests location permission for Auto Ticks.")
            case .authorizedWhenInUse:
                Button("Allow Background Automation") {
                    viewModel.requestAutoTickBackgroundLocationPermission()
                }
                .accessibilityHint("Requests background location access for geofenced Auto Tick rules.")
            case .authorizedAlways, .denied, .restricted, .unknown:
                EmptyView()
            }
        }
    }

    private var rulesSection: some View {
        Section("Rules") {
            if viewModel.autoTickRules.isEmpty {
                ContentUnavailableView(
                    "No Auto Ticks",
                    systemImage: "location.slash",
                    description: Text("Create a rule after choosing a project and current location.")
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

private struct AutoTickRuleRowView: View {
    let rule: AutoTickRule
    let projectName: String

    var body: some View {
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
                    .foregroundStyle(rule.isEnabled ? .green : .secondary)
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
        .padding(.vertical, 4)
        .accessibilityElement(children: .contain)
    }
}

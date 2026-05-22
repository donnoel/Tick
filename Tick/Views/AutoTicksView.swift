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
            Text("Auto Ticks stays off until you create and enable a location rule. Tick uses location only for saved Auto Tick rules.")
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
                    AutoTickRuleRowView(
                        rule: rule,
                        projectName: projectName(for: rule.projectID),
                        isEnabled: Binding {
                            viewModel.autoTickRule(for: rule.id)?.isEnabled ?? rule.isEnabled
                        } set: { isEnabled in
                            Task {
                                await viewModel.setAutoTickRule(rule.id, isEnabled: isEnabled)
                            }
                        }
                    )
                }
            }
        }
    }

    private func projectName(for projectID: TickProject.ID) -> String {
        viewModel.project(for: projectID)?.name ?? "Unknown Project"
    }
}

private struct AutoTickRuleRowView: View {
    let rule: AutoTickRule
    let projectName: String
    @Binding var isEnabled: Bool

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

                Toggle("Enabled", isOn: $isEnabled)
                    .labelsHidden()
                    .accessibilityLabel("\(rule.name) enabled")
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

import SwiftUI

struct AutoTicksView: View {
    let viewModel: TickViewModel
    @State private var isAddingRule = false

    var body: some View {
        NavigationStack {
            List {
                if shouldShowPermissionSection {
                    permissionSection
                }
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

    private var shouldShowPermissionSection: Bool {
        viewModel.autoTickLocationAuthorizationStatus != .authorizedAlways
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
                EmptyAutoTicksCard(
                    canAddRule: !viewModel.activeProjects.isEmpty,
                    addRule: { isAddingRule = true }
                )
                .listRowBackground(Color.clear)
            } else {
                ForEach(viewModel.autoTickRules) { rule in
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

private struct EmptyAutoTicksCard: View {
    let canAddRule: Bool
    let addRule: () -> Void

    var body: some View {
        VStack(alignment: .center, spacing: 16) {
            Image(systemName: "location.circle")
                .font(.system(size: 42, weight: .regular))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            VStack(alignment: .center, spacing: 6) {
                Text("No Auto Ticks yet")
                    .font(.headline)
                    .multilineTextAlignment(.center)

                Text("Add a place and Tick can start or stop for you.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 240)
            }
            .frame(maxWidth: .infinity, alignment: .center)

            Button {
                addRule()
            } label: {
                Label("Add Auto Tick", systemImage: "plus")
                    .frame(minWidth: 150)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
            .disabled(!canAddRule)
            .accessibilityHint(canAddRule ? "Create a location rule for automatic time tracking." : "Create a project before adding an Auto Tick rule.")
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, 28)
        .padding(.horizontal, 18)
        .tickCard(tint: TickPalette.primaryAction)
        .accessibilityElement(children: .contain)
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

            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 10) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(rule.name)
                            .font(.headline)
                            .foregroundStyle(.primary)
                            .lineLimit(1)

                        Text(projectName)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 8)

                    Text(rule.isEnabled ? "Enabled" : "Disabled")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(statusTint.opacity(0.14), in: Capsule())
                        .foregroundStyle(statusTint)
                        .lineLimit(1)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Label("\(Int(rule.radiusMeters.rounded())) meter radius", systemImage: "circle.dotted")

                    Text(automationSummary)
                        .font(.caption)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 8)
        .accessibilityElement(children: .contain)
    }

    private var statusTint: Color {
        rule.isEnabled ? TickPalette.locationReady : .secondary
    }

    private var automationSummary: String {
        switch (rule.startsOnArrival, rule.stopsOnDeparture) {
        case (true, true):
            "Starts on arrival · stops on departure"
        case (true, false):
            "Starts on arrival"
        case (false, true):
            "Stops on departure"
        case (false, false):
            "No automation behavior"
        }
    }
}

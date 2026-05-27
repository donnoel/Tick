import SwiftUI

struct AutoTicksView: View {
    let viewModel: TickViewModel
    @State private var isAddingRule = false

    private var isPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }

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
                    .accessibilityHint("Create a location rule for automatic time.")
                }
            }
            .sheet(isPresented: isAddingRuleSheetBinding) {
                AddAutoTickRuleView(viewModel: viewModel)
                    .presentationDetents([.large])
            }
            .fullScreenCover(isPresented: isAddingRuleFullScreenBinding) {
                AddAutoTickRuleView(viewModel: viewModel)
            }
        }
    }

    private var isAddingRuleSheetBinding: Binding<Bool> {
        Binding(
            get: { isAddingRule && !isPad },
            set: { isPresented in
                if !isPresented {
                    isAddingRule = false
                }
            }
        )
    }

    private var isAddingRuleFullScreenBinding: Binding<Bool> {
        Binding(
            get: { isAddingRule && isPad },
            set: { isPresented in
                if !isPresented {
                    isAddingRule = false
                }
            }
        )
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
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                .listRowBackground(Color.clear)
            } else {
                ForEach(viewModel.autoTickRules) { rule in
                    NavigationLink(value: rule.id) {
                        AutoTickRuleRowView(
                            rule: rule,
                            projectName: projectName(for: rule.projectID)
                        )
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .listRowBackground(Color.clear)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(ruleAccessibilityLabel(rule, projectName: projectName(for: rule.projectID)))
                    .accessibilityValue(ruleAccessibilityValue(rule))
                    .accessibilityHint("Opens this Auto Tick rule for editing.")
                }
            }
        }
    }

    private func projectName(for projectID: TickProject.ID) -> String {
        viewModel.project(for: projectID)?.name ?? "Unknown Space"
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
        VStack(alignment: .center, spacing: 18) {
            Image(systemName: "location.circle")
                .font(.system(size: 42, weight: .regular))
                .foregroundStyle(TickPalette.primaryAction)
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
                Text("Add Auto Tick")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
            .disabled(!canAddRule)
            .frame(width: 180)
            .accessibilityHint(canAddRule ? "Create a location rule for automatic time." : "Create a space before adding an Auto Tick rule.")
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, 30)
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
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                TickProjectBadge(color: TickProjectAccent.color(for: rule.projectID), systemImage: "location.fill")

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
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(statusTint.opacity(0.14), in: Capsule())
                    .foregroundStyle(statusTint)
                    .lineLimit(1)
            }

            HStack(alignment: .top, spacing: 10) {
                RuleMetric(
                    title: "Radius",
                    value: "\(Int(rule.radiusMeters.rounded())) m",
                    systemImage: "circle.dotted"
                )

                RuleMetric(
                    title: "Automation",
                    value: automationSummary,
                    systemImage: "arrow.triangle.2.circlepath"
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .tickCard(tint: statusTint, isHighlighted: rule.isEnabled)
        .accessibilityElement(children: .contain)
    }

    private var statusTint: Color {
        rule.isEnabled ? TickPalette.locationReady : .secondary
    }

    private var automationSummary: String {
        switch (rule.startsOnArrival, rule.stopsOnDeparture) {
        case (true, true):
            "Arrive + leave"
        case (true, false):
            "Arrive"
        case (false, true):
            "Leave"
        case (false, false):
            "Off"
        }
    }
}

private struct RuleMetric: View {
    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Label(title, systemImage: systemImage)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Text(value)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
    }
}

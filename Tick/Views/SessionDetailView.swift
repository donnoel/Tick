import SwiftUI

struct SessionDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let viewModel: TickViewModel
    let sessionID: TimeSession.ID
    @State private var title: String
    @State private var notes: String
    @State private var projectID: TickProject.ID?
    @State private var timing: SessionTimingDraft
    @State private var isSaving = false

    @MainActor
    init(viewModel: TickViewModel, session: TimeSession) {
        self.viewModel = viewModel
        self.sessionID = session.id
        _title = State(initialValue: session.title)
        _notes = State(initialValue: session.notes)
        _projectID = State(initialValue: session.projectID)
        _timing = State(initialValue: SessionTimingDraft(session: session))
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { timeline in
            if let session = viewModel.session(for: sessionID) {
                form(for: session, displayDate: timeline.date)
            } else {
                ContentUnavailableView(
                    "Session Missing",
                    systemImage: "clock.badge.exclamationmark",
                    description: Text("Tick could not find this session.")
                )
                .navigationTitle("Session")
            }
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
                        guard let projectID else {
                            return
                        }
                        isSaving = true
                        let didUpdate = await viewModel.updateSession(
                            id: sessionID,
                            title: title,
                            notes: notes,
                            projectID: projectID,
                            timing: timing.hasChanges ? timing : nil
                        )
                        isSaving = false
                        if didUpdate {
                            dismiss()
                        }
                    }
                }
                .disabled(projectID == nil || isSaving || (timing.hasChanges && timing.validationMessage != nil))
                .accessibilityIdentifier("sessionDetail.saveButton")
            }
        }
    }

    private func form(for session: TimeSession, displayDate: Date) -> some View {
        Form {
            Section("Details") {
                if projectOptions(for: session).isEmpty {
                    LabeledContent("Space", value: projectName(for: session.projectID))
                } else {
                    Picker("Space", selection: $projectID) {
                        ForEach(projectOptions(for: session)) { project in
                            Text(project.name).tag(Optional(project.id))
                        }
                    }
                    .accessibilityHint("Choose the space for this session.")
                }

                TextField("Title", text: $title)
                    .textInputAutocapitalization(.sentences)
                    .accessibilityIdentifier("sessionDetail.titleField")
                    .accessibilityLabel("Title")
                    .accessibilityHint("Edit the short title for this session.")

                TextField("Notes", text: $notes, axis: .vertical)
                    .lineLimit(3...8)
                    .textInputAutocapitalization(.sentences)
                    .accessibilityLabel("Notes")
                    .accessibilityHint("Edit notes for this session.")
            }

            Section("Timing") {
                if session.isActive {
                    LabeledContent("Date", value: session.referenceDate.formatted(date: .abbreviated, time: .omitted))
                    LabeledContent("Start", value: session.referenceDate.formatted(date: .omitted, time: .shortened))
                    LabeledContent("Duration", value: TickDurationFormatter.shortString(from: session.duration(at: displayDate)))
                    LabeledContent("Entry Source", value: sourceDescription(for: session.entrySource))
                    Text("Stop this Tick to edit its timing.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    DatePicker("Date", selection: $timing.startedAt, displayedComponents: .date)
                        .accessibilityIdentifier("sessionDetail.date")
                    DatePicker("Start", selection: $timing.startedAt, displayedComponents: .hourAndMinute)
                        .accessibilityIdentifier("sessionDetail.start")
                    if timing.source != .manual {
                        DatePicker("End", selection: Binding(get: { timing.endedAt }, set: { timing.endedAt = $0 }), displayedComponents: [.date, .hourAndMinute])
                            .accessibilityIdentifier("sessionDetail.end")
                            .accessibilityHint("Changing End updates the duration, excluding recorded pauses.")
                    }
                    DisclosureGroup {
                        Stepper("Hours: \(durationHours)", value: durationHoursBinding, in: 0...max(999_999, durationHours))
                            .accessibilityIdentifier("sessionDetail.durationHours")
                        Stepper("Minutes: \(durationMinutes)", value: durationMinutesBinding, in: 0...59)
                            .accessibilityIdentifier("sessionDetail.durationMinutes")
                        Stepper("Seconds: \(durationSeconds)", value: durationSecondsBinding, in: 0...59)
                            .accessibilityIdentifier("sessionDetail.durationSeconds")
                    } label: {
                        LabeledContent("Duration", value: TickSpaceReport.durationText(timing.duration))
                            .accessibilityIdentifier("sessionDetail.duration")
                    }
                    Picker("Entry Source", selection: $timing.source) {
                        ForEach(SessionEntrySource.allCases) { source in
                            Text(sourceDescription(for: source)).tag(source)
                        }
                    }
                    .accessibilityIdentifier("sessionDetail.source")
                    .accessibilityHint("Changes this recorded Tick's source. It does not start a timer or change Auto Tick rules.")
                    if timing.pausedDuration > 0 {
                        Text("Duration excludes \(TickSpaceReport.durationText(timing.pausedDuration)) of recorded pauses.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    if let message = timing.validationMessage, timing.hasChanges {
                        Text(message)
                            .foregroundStyle(.red)
                            .accessibilityIdentifier("sessionDetail.timingError")
                    }
                }
            }
        }
        .disabled(isSaving)
        .navigationTitle("Session")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var durationHours: Int { max(0, Int(timing.duration)) / 3_600 }
    private var durationMinutes: Int { (max(0, Int(timing.duration)) % 3_600) / 60 }
    private var durationSeconds: Int { max(0, Int(timing.duration)) % 60 }

    private var durationHoursBinding: Binding<Int> {
        Binding(get: { durationHours }, set: { timing.duration = Double($0 * 3_600 + durationMinutes * 60 + durationSeconds) })
    }
    private var durationMinutesBinding: Binding<Int> {
        Binding(get: { durationMinutes }, set: { timing.duration = Double(durationHours * 3_600 + $0 * 60 + durationSeconds) })
    }
    private var durationSecondsBinding: Binding<Int> {
        Binding(get: { durationSeconds }, set: { timing.duration = Double(durationHours * 3_600 + durationMinutes * 60 + $0) })
    }

    private func projectOptions(for session: TimeSession) -> [TickProject] {
        var options = viewModel.activeProjects

        if let currentProject = viewModel.project(for: session.projectID),
           !options.contains(where: { $0.id == currentProject.id }) {
            options.append(currentProject)
        }

        return TickProject.sortedByDisplayOrder(options)
    }

    private func projectName(for projectID: TickProject.ID) -> String {
        viewModel.project(for: projectID)?.name ?? "Unknown Space"
    }

    private func sourceDescription(for source: SessionEntrySource) -> String {
        switch source {
        case .timer:
            "Timer"
        case .manual:
            "Manual"
        case .autoLocation:
            "Auto Tick"
        }
    }
}

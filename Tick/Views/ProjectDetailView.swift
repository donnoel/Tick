import SwiftUI

struct ProjectDetailView: View {
    let viewModel: TickViewModel
    let project: TickProject
    @State private var deletionMessage: String?
    @State private var projectActionMessage: String?
    @State private var voiceMemoMessage: String?
    @State private var voiceMemoIDBeingRenamed: VoiceMemo.ID?
    @State private var voiceMemoRenameTitle = ""

    var body: some View {
        let currentProject = viewModel.project(for: project.id) ?? project
        let projectAccent = TickProjectAccent.color(for: currentProject.id, among: viewModel.projects.map(\.id))

        TimelineView(.periodic(from: .now, by: 60)) { timeline in
            List {
                Section {
                    ProjectSummaryCard(
                        project: currentProject,
                        duration: viewModel.totalDuration(for: currentProject.id, at: timeline.date),
                        color: projectAccent
                    )
                }
                .listRowBackground(Color.clear)

                if currentProject.isArchived {
                    Section {
                        Label("This space is archived.", systemImage: "archivebox")
                            .font(.subheadline)
                            .accessibilityLabel("Space status: archived.")
                    }
                }

                Section("Voice Memos") {
                    if currentProject.isArchived {
                        Label("Restore this space before recording new voice memos.", systemImage: "mic.slash")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .accessibilityLabel("Voice memo recording unavailable for archived space.")
                    } else if viewModel.isRecordingVoiceMemo(for: currentProject.id) {
                        HStack {
                            Label("Recording", systemImage: "mic.fill")
                                .foregroundStyle(.red)
                                .font(.subheadline.weight(.semibold))

                            Spacer()

                            Button {
                                stopRecordingVoiceMemo()
                            } label: {
                                Image(systemName: "stop.fill")
                                    .font(.headline)
                                    .frame(width: 44, height: 44)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.red)
                            .accessibilityLabel("Stop recording")
                            .accessibilityHint("Stops and saves this voice memo.")
                        }
                    } else {
                        Button {
                            startRecordingVoiceMemo(currentProject.id)
                        } label: {
                            Label("Record Voice Memo", systemImage: "mic")
                        }
                        .accessibilityHint("Starts a local voice memo for this space.")
                    }

                    let voiceMemos = viewModel.voiceMemos(for: currentProject.id)
                    if voiceMemos.isEmpty {
                        ContentUnavailableView(
                            "No Voice Memos",
                            systemImage: "waveform",
                            description: Text("Recorded memos for this space will appear here.")
                        )
                    } else {
                        ForEach(voiceMemos) { voiceMemo in
                            VoiceMemoRowView(
                                voiceMemo: voiceMemo,
                                isPlaying: viewModel.playingVoiceMemoID == voiceMemo.id
                            ) {
                                playVoiceMemo(voiceMemo.id)
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    deleteVoiceMemo(voiceMemo.id)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }

                                Button {
                                    beginRenamingVoiceMemo(voiceMemo)
                                } label: {
                                    Label("Rename", systemImage: "pencil")
                                }
                                .tint(.blue)
                            }
                            .accessibilityHint("Plays this voice memo. Swipe for rename and delete actions.")
                        }
                    }
                }

                Section("Sessions") {
                    let projectSessions = viewModel.sessions(for: currentProject.id)
                    let fallbackTitles = SessionFallbackTitleProvider.untitledSessionTitles(for: projectSessions)
                    if projectSessions.isEmpty {
                        ContentUnavailableView(
                            "No Ticks yet",
                            systemImage: "clock",
                            description: Text("Sessions for this space will appear here.")
                        )
                    } else {
                        ForEach(projectSessions) { session in
                            NavigationLink {
                                SessionDetailView(viewModel: viewModel, session: session)
                            } label: {
                                SessionRowView(
                                    session: session,
                                    projectID: currentProject.id,
                                    projectName: currentProject.name,
                                    displayDate: timeline.date,
                                    defaultTitle: fallbackTitles[session.id] ?? "Tick",
                                    detailStyle: .date,
                                    accentColor: projectAccent
                                )
                            }
                            .buttonStyle(.plain)
                            .accessibilityHint("Opens session details.")
                        }
                        .onDelete { indexSet in
                            deleteSessions(at: indexSet, from: projectSessions)
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(TickPalette.appBackground)
        }
        .navigationTitle(currentProject.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    if currentProject.isArchived {
                        Button {
                            restoreProject(currentProject.id)
                        } label: {
                            Label("Restore Space", systemImage: "arrow.uturn.backward.circle")
                        }
                    } else {
                        Button(role: .destructive) {
                            archiveProject(currentProject.id)
                        } label: {
                            Label("Archive Space", systemImage: "archivebox")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .accessibilityLabel("Space actions")
                .accessibilityHint("Shows actions for this space.")
            }
        }
        .alert("Could Not Delete", isPresented: deletionAlertIsPresented) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(deletionMessage ?? "Tick could not delete that session.")
        }
        .alert("Could Not Update Space", isPresented: projectActionAlertIsPresented) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(projectActionMessage ?? "Tick could not update that space.")
        }
        .alert("Could Not Update Voice Memo", isPresented: voiceMemoAlertIsPresented) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(voiceMemoMessage ?? "Tick could not update that voice memo.")
        }
        .alert("Rename Voice Memo", isPresented: voiceMemoRenameAlertIsPresented) {
            TextField("Title", text: $voiceMemoRenameTitle)
                .textInputAutocapitalization(.sentences)

            Button("Cancel", role: .cancel) {
                clearVoiceMemoRenameState()
            }

            Button("Save") {
                renameVoiceMemo()
            }
            .disabled(voiceMemoRenameTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        } message: {
            Text("Give this voice memo a short title.")
        }
    }

    private var deletionAlertIsPresented: Binding<Bool> {
        Binding {
            deletionMessage != nil
        } set: { isPresented in
            if !isPresented {
                deletionMessage = nil
            }
        }
    }

    private var projectActionAlertIsPresented: Binding<Bool> {
        Binding {
            projectActionMessage != nil
        } set: { isPresented in
            if !isPresented {
                projectActionMessage = nil
            }
        }
    }

    private var voiceMemoAlertIsPresented: Binding<Bool> {
        Binding {
            voiceMemoMessage != nil
        } set: { isPresented in
            if !isPresented {
                voiceMemoMessage = nil
            }
        }
    }

    private var voiceMemoRenameAlertIsPresented: Binding<Bool> {
        Binding {
            voiceMemoIDBeingRenamed != nil
        } set: { isPresented in
            if !isPresented {
                clearVoiceMemoRenameState()
            }
        }
    }

    private func deleteSessions(at indexSet: IndexSet, from sessions: [TimeSession]) {
        Task {
            for index in indexSet {
                let didDelete = await viewModel.deleteSession(id: sessions[index].id)
                if !didDelete {
                    deletionMessage = viewModel.errorMessage ?? "Tick could not delete that session."
                    return
                }
            }
        }
    }

    private func startRecordingVoiceMemo(_ projectID: TickProject.ID) {
        Task {
            let didStart = await viewModel.startRecordingVoiceMemo(for: projectID)
            if !didStart {
                voiceMemoMessage = viewModel.errorMessage ?? "Tick could not start that voice memo."
            }
        }
    }

    private func stopRecordingVoiceMemo() {
        Task {
            let didStop = await viewModel.stopRecordingVoiceMemo()
            if !didStop {
                voiceMemoMessage = viewModel.errorMessage ?? "Tick could not stop that voice memo."
            }
        }
    }

    private func playVoiceMemo(_ voiceMemoID: VoiceMemo.ID) {
        Task {
            let didPlay = await viewModel.playVoiceMemo(id: voiceMemoID)
            if !didPlay {
                voiceMemoMessage = viewModel.errorMessage ?? "Tick could not play that voice memo."
            }
        }
    }

    private func beginRenamingVoiceMemo(_ voiceMemo: VoiceMemo) {
        voiceMemoIDBeingRenamed = voiceMemo.id
        voiceMemoRenameTitle = ""
    }

    private func renameVoiceMemo() {
        guard let voiceMemoIDBeingRenamed else {
            return
        }
        let title = voiceMemoRenameTitle
        clearVoiceMemoRenameState()

        Task {
            let didRename = await viewModel.updateVoiceMemoTitle(
                id: voiceMemoIDBeingRenamed,
                title: title
            )

            if !didRename {
                voiceMemoMessage = viewModel.errorMessage ?? "Tick could not rename that voice memo."
            }
        }
    }

    private func deleteVoiceMemo(_ voiceMemoID: VoiceMemo.ID) {
        Task {
            let didDelete = await viewModel.deleteVoiceMemo(id: voiceMemoID)
            if !didDelete {
                voiceMemoMessage = viewModel.errorMessage ?? "Tick could not delete that voice memo."
            }
        }
    }

    private func clearVoiceMemoRenameState() {
        voiceMemoIDBeingRenamed = nil
        voiceMemoRenameTitle = ""
    }

    private func archiveProject(_ projectID: TickProject.ID) {
        Task {
            let didArchive = await viewModel.archiveProject(id: projectID)
            if !didArchive {
                projectActionMessage = viewModel.errorMessage ?? "Tick could not archive that space."
            }
        }
    }

    private func restoreProject(_ projectID: TickProject.ID) {
        Task {
            let didRestore = await viewModel.restoreProject(id: projectID)
            if !didRestore {
                projectActionMessage = viewModel.errorMessage ?? "Tick could not restore that space."
            }
        }
    }
}

private struct ProjectSummaryCard: View {
    let project: TickProject
    let duration: TimeInterval
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                TickProjectBadge(color: color, systemImage: "folder.fill")

                VStack(alignment: .leading, spacing: 4) {
                    Text(project.name)
                        .font(.headline)

                    Text("Created \(project.createdAt.formatted(date: .abbreviated, time: .omitted))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Text(TickDurationFormatter.shortString(from: duration))
                .font(.system(.largeTitle, design: .rounded).weight(.bold))
                .monospacedDigit()
                .minimumScaleFactor(0.75)
                .lineLimit(1)

            Text("Total recorded")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .tickCard(tint: color)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(project.name), \(TickDurationFormatter.shortString(from: duration)) total recorded, created \(project.createdAt.formatted(date: .abbreviated, time: .omitted))")
    }
}

private struct VoiceMemoRowView: View {
    let voiceMemo: VoiceMemo
    let isPlaying: Bool
    let togglePlayback: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: togglePlayback) {
                Image(systemName: isPlaying ? "stop.circle.fill" : "play.circle.fill")
                    .font(.title2)
                    .symbolRenderingMode(.hierarchical)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isPlaying ? "Stop voice memo" : "Play voice memo")
            .accessibilityHint(isPlaying ? "Stops playback." : "Plays this voice memo.")

            VStack(alignment: .leading, spacing: 4) {
                Text(voiceMemo.title)
                    .font(.subheadline.weight(.semibold))

                Text("\(voiceMemo.createdAt.formatted(date: .abbreviated, time: .shortened)) - \(TickDurationFormatter.shortString(from: voiceMemo.duration))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(voiceMemo.title), \(TickDurationFormatter.shortString(from: voiceMemo.duration)), recorded \(voiceMemo.createdAt.formatted(date: .abbreviated, time: .shortened))")
        }
    }
}

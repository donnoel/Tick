import CloudKit
import SwiftUI
import TickCore

struct TickWatchView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var viewModel = TickWatchViewModel()
    @State private var isChoosingSpace = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 10) {
                    spaceControl
                    timer
                    controls
                    if let message = viewModel.errorMessage {
                        Text(message).font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)
                        Button("Try Again", systemImage: "arrow.clockwise") { Task { await viewModel.refresh() } }
                            .disabled(viewModel.isRefreshing || viewModel.isActing)
                    } else if let message = viewModel.syncMessage {
                        Text(message).font(.caption2).foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 4)
            }
            .navigationTitle("Ticks")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $isChoosingSpace) {
                TickWatchSpacePicker(viewModel: viewModel)
            }
            .task(id: scenePhase) {
                guard scenePhase == .active else { return }
                await viewModel.refresh()
            }
            .task(id: shouldRetryPendingChanges) {
                guard shouldRetryPendingChanges else { return }
                // Only unsynced changes receive a few foreground retries. Going
                // inactive cancels the sleep; no background polling is scheduled.
                for delay in [60, 120, 240] {
                    do { try await Task.sleep(for: .seconds(delay)) }
                    catch { return }
                    guard !Task.isCancelled, shouldRetryPendingChanges else { return }
                    await viewModel.refresh()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: TickWatchConnectivity.refreshNotification)) { _ in
                guard scenePhase == .active else { return }
                Task { await viewModel.refresh() }
            }
            .onReceive(NotificationCenter.default.publisher(for: .CKAccountChanged)) { _ in
                guard scenePhase == .active else { return }
                Task { await viewModel.refresh() }
            }
        }
        .tint(accent)
    }

    private var spaceControl: some View {
        Group {
            if viewModel.activeSession != nil {
                Text(viewModel.displayedSpace?.name ?? "Space")
                    .font(.headline).foregroundStyle(accent).multilineTextAlignment(.center)
                    .accessibilityLabel("Active Space, \(viewModel.displayedSpace?.name ?? "Space")")
            } else if !viewModel.spaces.isEmpty {
                Button { isChoosingSpace = true } label: {
                    HStack(spacing: 6) {
                        Text(viewModel.displayedSpace?.name ?? "Choose Space").font(.headline)
                        Image(systemName: "chevron.down").font(.caption)
                    }.frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
                .frame(minHeight: 44)
                .accessibilityLabel("Choose Space")
                .accessibilityValue(viewModel.displayedSpace?.name ?? "None selected")
                .accessibilityHint("Choose an existing Space to record time.")
                .disabled(viewModel.isActing)
            } else {
                Text(viewModel.hasLoaded ? "Create a Space in Tick on your iPhone or iPad." : "Loading Spaces…")
                    .font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)
            }
        }
    }

    private var timer: some View {
            VStack(spacing: 4) {
                Group {
                    if let session = viewModel.activeSession, session.pausedAt == nil, let start = session.startedAt {
                        // watchOS owns display updates (including Always On).
                        // There is no Timer, periodic TimelineView, or stored tick counter.
                        Text(start.addingTimeInterval(session.accumulatedPausedDuration ?? 0), style: .timer)
                    } else {
                        Text(TickDurationFormatter.timerString(from: viewModel.activeSession?.duration(at: .now) ?? 0))
                    }
                }
                    .font(.system(.largeTitle, design: .rounded, weight: .medium))
                    .monospacedDigit().minimumScaleFactor(0.65).lineLimit(1)
                    .contentTransition(.identity)
                Text(viewModel.activeSession == nil ? "Ready" : viewModel.isPaused ? "Paused" : "Elapsed")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .combine)
    }

    private var shouldRetryPendingChanges: Bool {
        scenePhase == .active && viewModel.state.hasPendingChanges && !viewModel.writesBlocked
    }

    @ViewBuilder private var controls: some View {
        if viewModel.activeSession != nil {
            HStack(spacing: 10) {
                Button { Task { await viewModel.pauseOrResume() } } label: {
                    Label(viewModel.isPaused ? "Resume" : "Pause", systemImage: viewModel.isPaused ? "play.fill" : "pause.fill")
                        .labelStyle(.iconOnly).frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .frame(minHeight: 44)
                .accessibilityLabel(viewModel.isPaused ? "Resume Tick" : "Pause Tick")
                .accessibilityHint(viewModel.isPaused ? "Continue recording the same Tick." : "Paused time won't be recorded.")
                .disabled(!viewModel.canRecord)
                Button { Task { await viewModel.stop() } } label: {
                    Label("Stop", systemImage: "stop.fill").labelStyle(.iconOnly)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .frame(minHeight: 44)
                .accessibilityLabel("Stop Tick")
                .accessibilityHint("Save this Tick and return to the ready screen.")
                .disabled(!viewModel.canRecord)
            }
        } else {
            Button { Task { await viewModel.start() } } label: {
                Label(viewModel.isActing ? "Starting…" : "Start Tick", systemImage: "play.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .frame(minHeight: 44)
            .disabled(!viewModel.canStart)
            .accessibilityHint("Start recording time for the selected Space.")
        }
    }

    private var accent: Color {
        viewModel.displayedSpace.map { TickProjectAccent.color(for: $0.id, among: viewModel.state.snapshot.projects.map(\.id)) } ?? .blue
    }
}

private struct TickWatchSpacePicker: View {
    @Environment(\.dismiss) private var dismiss
    let viewModel: TickWatchViewModel

    var body: some View {
        NavigationStack {
            List(viewModel.spaces) { space in
                Button {
                    guard viewModel.activeSession == nil else { dismiss(); return }
                    viewModel.selectedSpaceID = space.id
                    dismiss()
                } label: {
                    HStack {
                        Text(space.name)
                        Spacer()
                        if space.id == viewModel.selectedSpaceID { Image(systemName: "checkmark").accessibilityHidden(true) }
                    }
                }
                .accessibilityLabel(space.name)
                .accessibilityValue(space.id == viewModel.selectedSpaceID ? "Selected" : "")
            }
            .navigationTitle("Spaces")
        }
        .onChange(of: viewModel.activeSession?.id) { _, sessionID in
            if sessionID != nil { dismiss() }
        }
    }
}

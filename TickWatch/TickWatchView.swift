import CloudKit
import SwiftUI
import TickCore

struct TickWatchView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.isLuminanceReduced) private var isLuminanceReduced
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .body) private var controlDiameter = 64
    @ScaledMetric(relativeTo: .largeTitle) private var timerFontSize = 32
    @State private var viewModel = TickWatchViewModel()
    @State private var isChoosingSpace = false

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ScrollView {
                    VStack(spacing: 6) {
                        spaceControl
                        timer
                        controls
                        if let message = viewModel.errorMessage {
                            Text(message).font(.footnote).foregroundStyle(secondaryInk).multilineTextAlignment(.center)
                            Button("Try Again", systemImage: "arrow.clockwise") { Task { await viewModel.refresh() } }
                                .disabled(viewModel.isRefreshing || viewModel.isActing)
                        } else if let message = viewModel.syncMessage {
                            Text(message).font(.caption2).foregroundStyle(secondaryInk)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.top, 4)
                    .padding(.bottom, 16)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: geometry.size.height)
                }
                .contentMargins(.vertical, 0, for: .scrollContent)
            }
            .foregroundStyle(ink)
            .containerBackground(for: .navigation) { TickWatchPalette.background(dimmed: isLuminanceReduced) }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarForegroundStyle(ink, for: .navigationBar)
            .toolbarColorScheme(isLuminanceReduced ? .dark : .light, for: .navigationBar)
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
        .tint(ink)
        .preferredColorScheme(isLuminanceReduced ? .dark : .light)
        .environment(\.colorScheme, isLuminanceReduced ? .dark : .light)
    }

    private var spaceControl: some View {
        Group {
            if viewModel.activeSession != nil {
                Text(viewModel.displayedSpace?.name ?? "Space")
                    .font(.headline).foregroundStyle(ink).multilineTextAlignment(.center)
                    .frame(minHeight: 24)
                    .accessibilityLabel("Active Space, \(viewModel.displayedSpace?.name ?? "Space")")
            } else if !viewModel.spaces.isEmpty {
                Button { isChoosingSpace = true } label: {
                    Text(viewModel.displayedSpace?.name ?? "Choose Space").font(.headline)
                    .padding(.horizontal, 14)
                    .frame(minWidth: 44, minHeight: 44)
                }
                .buttonStyle(.plain)
                .modifier(TickWatchGlassSurface(shape: Capsule()))
                .accessibilityLabel("Choose Space")
                .accessibilityValue(viewModel.displayedSpace?.name ?? "None selected")
                .accessibilityHint("Choose an existing Space to record time.")
                .disabled(viewModel.isActing)
            } else {
                Text(viewModel.hasLoaded ? "Create a Space in Tick on your iPhone or iPad." : "Loading Spaces…")
                    .font(.footnote).foregroundStyle(secondaryInk).multilineTextAlignment(.center)
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
                    .font(.system(size: timerFontSize, weight: .regular, design: .rounded))
                    .monospacedDigit().minimumScaleFactor(0.65).lineLimit(1)
                    .contentTransition(.identity)
                Text(viewModel.activeSession == nil ? "Ready" : viewModel.isPaused ? "Paused" : "Running")
                    .font(.caption).foregroundStyle(secondaryInk)
            }
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .combine)
    }

    private var shouldRetryPendingChanges: Bool {
        scenePhase == .active && viewModel.state.hasPendingChanges && !viewModel.writesBlocked
    }

    @ViewBuilder private var controls: some View {
        if viewModel.activeSession != nil {
            GlassEffectContainer(spacing: 18) {
                controlLayout {
                    Button { Task { await viewModel.pauseOrResume() } } label: {
                        actionLabel(viewModel.isPaused ? "Resume" : "Pause", symbol: viewModel.isPaused ? "play.fill" : "pause.fill")
                    }
                    .buttonStyle(.plain)
                    .modifier(TickWatchGlassSurface(shape: Circle(), prominent: true))
                    .accessibilityLabel(viewModel.isPaused ? "Resume Tick" : "Pause Tick")
                    .accessibilityHint(viewModel.isPaused ? "Continue recording the same Tick." : "Paused time won't be recorded.")
                    .disabled(!viewModel.canRecord)
                    Button { Task { await viewModel.stop() } } label: {
                        actionLabel("Stop", symbol: "stop.fill")
                    }
                    .buttonStyle(.plain)
                    .modifier(TickWatchGlassSurface(shape: Circle()))
                    .accessibilityLabel("Stop Tick")
                    .accessibilityHint("Save this Tick and return to the ready screen.")
                    .disabled(!viewModel.canRecord)
                }
            }
        } else {
            Button { Task { await viewModel.start() } } label: {
                Label(viewModel.isActing ? "Starting…" : "Start Tick", systemImage: "play.fill")
                    .font(.body)
                    .padding(.horizontal, 18)
                    .frame(minHeight: 52)
            }
            .buttonStyle(.plain)
            .modifier(TickWatchGlassSurface(shape: Capsule(), prominent: true))
            .disabled(!viewModel.canStart)
            .accessibilityHint("Start recording time for the selected Space.")
        }
    }

    private func actionLabel(_ title: String, symbol: String) -> some View {
        VStack(spacing: 5) {
            Image(systemName: symbol).font(.title3).accessibilityHidden(true)
            Text(title).font(.caption2)
        }
        .frame(width: controlDiameter, height: controlDiameter)
        .contentShape(Circle())
    }

    private var ink: Color { isLuminanceReduced ? TickWatchPalette.dimmedInk : TickWatchPalette.ink }
    private var secondaryInk: Color { isLuminanceReduced ? TickWatchPalette.dimmedInk : TickWatchPalette.secondaryInk }
    private var controlLayout: AnyLayout {
        dynamicTypeSize.isAccessibilitySize ? AnyLayout(VStackLayout(spacing: 18)) : AnyLayout(HStackLayout(spacing: 18))
    }
}

private struct TickWatchSpacePicker: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.isLuminanceReduced) private var isLuminanceReduced
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
                .foregroundStyle(isLuminanceReduced ? TickWatchPalette.dimmedInk : TickWatchPalette.ink)
                .listRowBackground(isLuminanceReduced ? TickWatchPalette.dimmedSurface : Color.white.opacity(0.45))
                .accessibilityLabel(space.name)
                .accessibilityValue(space.id == viewModel.selectedSpaceID ? "Selected" : "")
            }
            .navigationTitle("Spaces")
            .toolbarForegroundStyle(isLuminanceReduced ? TickWatchPalette.dimmedInk : TickWatchPalette.ink, for: .navigationBar)
            .containerBackground(for: .navigation) { TickWatchPalette.background(dimmed: isLuminanceReduced) }
        }
        .onChange(of: viewModel.activeSession?.id) { _, sessionID in
            if sessionID != nil { dismiss() }
        }
    }
}

private enum TickWatchPalette {
    static let ink = Color(red: 0.16, green: 0.31, blue: 0.41)
    static let secondaryInk = Color(red: 0.29, green: 0.40, blue: 0.49)
    static let blue = Color(red: 0.65, green: 0.84, blue: 0.96)
    static let dimmedSurface = Color(red: 0.04, green: 0.10, blue: 0.15)
    static let dimmedInk = Color(red: 0.71, green: 0.83, blue: 0.91)

    @ViewBuilder static func background(dimmed: Bool) -> some View {
        if dimmed {
            dimmedSurface
        } else {
            LinearGradient(colors: [
                Color(red: 0.98, green: 0.99, blue: 1),
                Color(red: 0.93, green: 0.97, blue: 1),
                Color(red: 0.80, green: 0.91, blue: 0.98)
            ], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }
}

private struct TickWatchGlassSurface<S: InsettableShape>: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.isLuminanceReduced) private var isLuminanceReduced
    @Environment(\.isEnabled) private var isEnabled
    let shape: S
    var prominent = false

    @ViewBuilder func body(content: Content) -> some View {
        Group {
            if reduceTransparency || isLuminanceReduced {
                content.background(isLuminanceReduced ? TickWatchPalette.dimmedSurface : TickWatchPalette.blue, in: shape)
                    .overlay { shape.strokeBorder(TickWatchPalette.ink.opacity(0.25), lineWidth: 1) }
            } else {
                content.glassEffect(.clear.tint(prominent ? TickWatchPalette.blue.opacity(0.35) : nil).interactive(isEnabled), in: shape)
                    .overlay {
                        if contrast == .increased { shape.strokeBorder(TickWatchPalette.ink.opacity(0.5), lineWidth: 1) }
                    }
            }
        }
        .opacity(isEnabled ? 1 : 0.45)
    }
}

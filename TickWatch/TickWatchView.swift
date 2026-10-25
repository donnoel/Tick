import CloudKit
import SwiftUI
import TickCore

struct TickWatchView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.isLuminanceReduced) private var isLuminanceReduced
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .caption2) private var controlHeight = 44
    @ScaledMetric(relativeTo: .caption2) private var statusHeight = 18
    @ScaledMetric(relativeTo: .subheadline) private var spaceFontSize = 16
    @ScaledMetric(relativeTo: .footnote) private var controlFontSize = 14
    @ScaledMetric(relativeTo: .caption2) private var statusFontSize = 12
    @ScaledMetric(relativeTo: .largeTitle) private var timerFontSize = 34
    @State private var viewModel = TickWatchViewModel()
    @State private var isChoosingSpace = false

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ScrollView {
                    VStack(spacing: 12) {
                        spaceControl
                        timer
                        controls
                        if let message = viewModel.errorMessage {
                            Text(message).font(.caption2).foregroundStyle(secondaryInk).multilineTextAlignment(.center)
                            Button("Try Again", systemImage: "arrow.clockwise") { Task { await viewModel.refresh() } }
                                .disabled(viewModel.isRefreshing || viewModel.isActing)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.top, 4)
                    .padding(.bottom, 20)
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
            if !viewModel.spaces.isEmpty {
                Button { isChoosingSpace = true } label: {
                    HStack(spacing: 6) {
                        Text(viewModel.displayedSpace?.name ?? "Choose Space")
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        if viewModel.activeSessionCount == 2 {
                            Text("2 active")
                                .font(.system(size: statusFontSize, weight: .semibold))
                                .foregroundStyle(secondaryInk)
                        }
                    }
                        .padding(.horizontal, 14)
                        .frame(minWidth: 44, minHeight: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Choose Space")
                .accessibilityValue(viewModel.activeSessionCount == 2
                    ? "\(viewModel.displayedSpace?.name ?? "None selected"), 2 Ticks active"
                    : viewModel.displayedSpace?.name ?? "None selected")
                .accessibilityHint("Choose the Space and its Tick to control.")
                .disabled(viewModel.isActing)
            } else {
                Text(viewModel.hasLoaded ? "Create a Space in Tick on your iPhone or iPad." : "Spaces")
                    .font(.footnote).foregroundStyle(secondaryInk).multilineTextAlignment(.center)
            }
        }
        .font(.system(size: spaceFontSize, weight: .medium))
        .frame(minHeight: 44)
    }

    private var timer: some View {
            VStack(spacing: 6) {
                Group {
                    if let session = viewModel.activeSession, session.pausedAt == nil, let start = session.startedAt {
                        // watchOS owns display updates (including Always On).
                        // There is no Timer, periodic TimelineView, or stored tick counter.
                        Text(start.addingTimeInterval(session.accumulatedPausedDuration ?? 0), style: .timer)
                    } else {
                        Text(TickDurationFormatter.timerString(from: viewModel.activeSession?.duration(at: .now) ?? 0))
                    }
                }
                    .font(.system(size: timerFontSize, weight: .medium, design: .rounded))
                    .monospacedDigit().minimumScaleFactor(0.65).lineLimit(1)
                    .contentTransition(.identity)
                Text(statusText)
                    .font(.system(size: statusFontSize)).foregroundStyle(secondaryInk)
                    .lineLimit(1).minimumScaleFactor(0.85)
                    .frame(height: statusHeight)
                    .accessibilityHidden(statusText.isEmpty)
            }
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("watch-timer")
    }

    private var statusText: String {
        if let syncMessage = viewModel.syncMessage {
            guard viewModel.activeSession != nil else { return syncMessage }
            return viewModel.isPaused ? "Paused · Syncing" : "Running · Syncing"
        }
        guard viewModel.activeSession != nil else { return "" }
        return viewModel.isPaused ? "Paused" : "Running"
    }

    private var shouldRetryPendingChanges: Bool {
        scenePhase == .active && viewModel.state.hasPendingChanges && !viewModel.writesBlocked
    }

    @ViewBuilder private var controls: some View {
        if viewModel.activeSession != nil {
            GlassEffectContainer(spacing: 12) {
                controlLayout {
                    Button { Task { await viewModel.pauseOrResume() } } label: {
                        actionLabel(viewModel.isPaused ? "Resume" : "Pause")
                    }
                    .buttonStyle(.plain)
                    .modifier(TickWatchGlassSurface(shape: Capsule(), prominent: true))
                    .accessibilityLabel(viewModel.isPaused ? "Resume Tick" : "Pause Tick")
                    .accessibilityHint(viewModel.isPaused ? "Continue recording the same Tick." : "Paused time won't be recorded.")
                    .disabled(!viewModel.canRecord)
                    Button { Task { await viewModel.stop() } } label: {
                        actionLabel("Stop")
                    }
                    .buttonStyle(.plain)
                    .modifier(TickWatchGlassSurface(shape: Capsule()))
                    .accessibilityLabel("Stop Tick")
                    .accessibilityHint("Save this Tick and return to the ready screen.")
                    .disabled(!viewModel.canRecord)
                }
            }
        } else {
            Button { Task { await viewModel.start() } } label: {
                actionLabel(viewModel.isActing ? "Starting…" : "Start Tick", symbol: "play.fill")
            }
            .buttonStyle(.plain)
            .modifier(TickWatchGlassSurface(shape: Capsule(), prominent: true))
            .disabled(!viewModel.canStart)
            .accessibilityHint("Start recording time for the selected Space.")
        }
    }

    private func actionLabel(_ title: String, symbol: String? = nil) -> some View {
        Group {
            if let symbol { Label(title, systemImage: symbol) }
            else { Text(title) }
        }
            .font(.system(size: controlFontSize, weight: .medium))
            .lineLimit(1).minimumScaleFactor(0.85)
            .padding(.horizontal, 6)
            .frame(maxWidth: .infinity, minHeight: max(44, controlHeight))
            .contentShape(Capsule())
    }

    private var ink: Color { isLuminanceReduced ? TickWatchPalette.dimmedInk : TickWatchPalette.ink }
    private var secondaryInk: Color { isLuminanceReduced ? TickWatchPalette.dimmedInk : TickWatchPalette.secondaryInk }
    private var controlLayout: AnyLayout {
        dynamicTypeSize.isAccessibilitySize ? AnyLayout(VStackLayout(spacing: 12)) : AnyLayout(HStackLayout(spacing: 12))
    }
}

private struct TickWatchSpacePicker: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.isLuminanceReduced) private var isLuminanceReduced
    let viewModel: TickWatchViewModel

    var body: some View {
        NavigationStack {
            List(viewModel.pickerSpaces) { space in
                Button {
                    viewModel.selectedSpaceID = space.id
                    dismiss()
                } label: {
                    HStack {
                        Text(space.name)
                        Spacer()
                        if let session = viewModel.activeSession(for: space.id) {
                            Text(session.pausedAt == nil ? "Running" : "Paused")
                                .font(.caption2)
                        }
                        if space.id == viewModel.selectedSpaceID { Image(systemName: "checkmark").accessibilityHidden(true) }
                    }
                }
                .foregroundStyle(isLuminanceReduced ? TickWatchPalette.dimmedInk : TickWatchPalette.ink)
                .listRowBackground(isLuminanceReduced ? TickWatchPalette.dimmedSurface : Color.white.opacity(0.45))
                .accessibilityLabel(space.name)
                .accessibilityValue([
                    viewModel.activeSession(for: space.id).map { $0.pausedAt == nil ? "Running" : "Paused" },
                    space.id == viewModel.selectedSpaceID ? "Selected" : nil
                ].compactMap { $0 }.joined(separator: ", "))
            }
            .navigationTitle("Spaces")
            .toolbarForegroundStyle(isLuminanceReduced ? TickWatchPalette.dimmedInk : TickWatchPalette.ink, for: .navigationBar)
            .containerBackground(for: .navigation) { TickWatchPalette.background(dimmed: isLuminanceReduced) }
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

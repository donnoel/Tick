import CloudKit
import Foundation
import Observation
import TickCore
import WatchKit

@MainActor
@Observable
final class TickWatchViewModel {
    private(set) var state = TickCloudClientState()
    private(set) var hasLoaded = false
    private(set) var isActing = false
    private(set) var isRefreshing = false
    private(set) var errorMessage: String?
    private(set) var writesBlocked = false
    var selectedSpaceID: UUID? {
        didSet { defaults.set(selectedSpaceID?.uuidString, forKey: "watch.selectedSpaceID") }
    }
    @ObservationIgnored private let store: TickCloudClientStore
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private var refreshRequested = false

    init(store: TickCloudClientStore = TickWatchServices.store, defaults: UserDefaults = .standard) {
        self.store = store
        self.defaults = defaults
        selectedSpaceID = defaults.string(forKey: "watch.selectedSpaceID").flatMap(UUID.init(uuidString:))
    }

    var spaces: [TickWidgetStoredProject] {
        TickWidgetStoredProject.activeSortedByDisplayOrder(state.snapshot.projects)
    }
    var activeSession: TickWidgetStoredSession? { state.snapshot.sessions.first(where: \.isActive) }
    var displayedSpace: TickWidgetStoredProject? {
        state.snapshot.projects.first { $0.id == (activeSession?.projectID ?? selectedSpaceID) }
    }
    var isPaused: Bool { activeSession?.pausedAt != nil }
    var canRecord: Bool { state.canRecord && !writesBlocked && !isActing && !isRefreshing }
    var canStart: Bool { canRecord && activeSession == nil && spaces.contains { $0.id == selectedSpaceID } }
    var syncMessage: String? {
        if state.hasPendingChanges { return "Waiting to sync" }
        if !hasLoaded { return "Loading Spaces…" }
        return nil
    }

    func refresh() async {
        guard !isActing else { refreshRequested = true; return }
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        do {
            // Load cached data first so opening the Watch app remains responsive.
            if !hasLoaded { apply(try await store.load()) }
            apply(try await store.refresh())
            writesBlocked = false
            errorMessage = nil
        } catch { await handle(error) }
        hasLoaded = true
    }

    func start() async {
        guard canStart, let selectedSpaceID else { return }
        await perform(.start(projectID: selectedSpaceID, sessionID: UUID(), at: .now))
    }
    func pauseOrResume() async {
        guard canRecord, let session = activeSession else { return }
        await perform(session.pausedAt == nil ? .pause(sessionID: session.id, at: .now) : .resume(sessionID: session.id, at: .now))
    }
    func stop() async {
        guard canRecord, let session = activeSession else { return }
        await perform(.stop(sessionID: session.id, at: .now))
    }

    private func perform(_ action: TickCloudClientAction) async {
        guard !isActing else { return }
        isActing = true
        do {
            apply(try await store.perform(action))
            errorMessage = nil
            writesBlocked = false
            WKInterfaceDevice.current().play(.click)
        } catch { await handle(error) }
        isActing = false
        await refresh()
        if !state.hasPendingChanges, !writesBlocked { TickWatchConnectivity.shared.notifyCounterpart() }
        if refreshRequested {
            refreshRequested = false
            await refresh()
        }
    }

    private func handle(_ error: any Error) async {
        if let cached = try? await store.load() { apply(cached) }
        let temporary = TickCloudClientStore.isTemporaryCloudFailure(error)
        writesBlocked = !temporary && !(error is TickTimerMutation.Failure)
        // Pending changes already have a quiet, visible waiting-to-sync state.
        if temporary && state.canRecord {
            errorMessage = nil
        } else if let cloudError = error as? CKError {
            switch cloudError.code {
            case .notAuthenticated:
                errorMessage = "Sign in to iCloud on your iPhone to load your Spaces."
            case .permissionFailure:
                errorMessage = "iCloud access isn't ready for Ticks on this Watch. Try again shortly."
            default:
                errorMessage = "Ticks couldn't connect to iCloud. Try again when you're connected."
            }
        } else {
            errorMessage = error.localizedDescription
        }
    }

    private func apply(_ state: TickCloudClientState) {
        self.state = state
        if !spaces.contains(where: { $0.id == selectedSpaceID }) { selectedSpaceID = spaces.first?.id }
    }
}

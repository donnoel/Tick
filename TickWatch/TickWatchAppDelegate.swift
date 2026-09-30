import CloudKit
import Foundation
import OSLog
import TickCore
import WatchKit
import WatchConnectivity

@MainActor
final class TickWatchAppDelegate: NSObject, WKApplicationDelegate {
    private var connectivityTasks: Set<WKWatchConnectivityRefreshBackgroundTask> = []
    private var activationObservation: NSKeyValueObservation?
    private var pendingObservation: NSKeyValueObservation?
    private let logger = Logger(subsystem: "dn.tick.watchkitapp", category: "CloudSync")

    func applicationDidFinishLaunching() {
        #if targetEnvironment(simulator)
        return
        #else
        WKApplication.shared().registerForRemoteNotifications()
        activationObservation = WCSession.default.observe(\.activationState) { [weak self] _, _ in
            Task { @MainActor in self?.finishConnectivityTasksIfReady() }
        }
        pendingObservation = WCSession.default.observe(\.hasContentPending) { [weak self] _, _ in
            Task { @MainActor in self?.finishConnectivityTasksIfReady() }
        }
        TickWatchConnectivity.shared.activate()
        #endif
    }

    func handle(_ backgroundTasks: Set<WKRefreshBackgroundTask>) {
        for task in backgroundTasks {
            if let connectivity = task as? WKWatchConnectivityRefreshBackgroundTask {
                connectivityTasks.insert(connectivity)
            } else if let snapshot = task as? WKSnapshotRefreshBackgroundTask {
                snapshot.setTaskCompleted(restoredDefaultState: false,
                                          estimatedSnapshotExpiration: .distantFuture, userInfo: nil)
            } else {
                task.setTaskCompletedWithSnapshot(false)
            }
        }
        finishConnectivityTasksIfReady()
    }

    private func finishConnectivityTasksIfReady() {
        guard !connectivityTasks.isEmpty, WCSession.default.activationState == .activated,
              !WCSession.default.hasContentPending else { return }
        let tasks = connectivityTasks
        connectivityTasks.removeAll()
        Task {
            // One refresh per delivered batch, then release the system's runtime.
            _ = try? await TickWatchServices.store.refresh()
            NotificationCenter.default.post(name: TickWatchConnectivity.refreshNotification, object: nil)
            for task in tasks { task.setTaskCompletedWithSnapshot(false) }
        }
    }

    func didReceiveRemoteNotification(_ userInfo: [AnyHashable: Any]) async -> WKBackgroundFetchResult {
        guard CKNotification(fromRemoteNotificationDictionary: userInfo)?.subscriptionID == TickWatchServices.subscriptionID else {
            return .noData
        }
        do {
            _ = try await TickWatchServices.store.refresh()
            NotificationCenter.default.post(name: TickWatchConnectivity.refreshNotification, object: nil)
            return .newData
        } catch {
            logger.info("Cloud refresh deferred; local time is preserved")
            return .failed
        }
    }

    func didFailToRegisterForRemoteNotificationsWithError(_ error: any Error) {
        logger.info("Cloud notifications unavailable; foreground refresh remains enabled")
    }
}

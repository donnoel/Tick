import Foundation
import WatchConnectivity

/// Sends refresh hints only. Timer records and account separation remain in
/// CloudKit, so the two delivery paths cannot execute an action twice.
nonisolated final class TickWatchConnectivity: NSObject, WCSessionDelegate, Sendable {
    static let shared = TickWatchConnectivity()
    static let refreshNotification = Notification.Name("tick.watchRefreshRequested")
    private static let hintKey = "tick.cloudChanged.v1"

    func activate() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    func notifyCounterpart() {
        guard WCSession.isSupported(), WCSession.default.activationState == .activated else { return }
        #if os(iOS)
        guard WCSession.default.isPaired, WCSession.default.isWatchAppInstalled else { return }
        #endif
        let hint: [String: Any] = [Self.hintKey: Date.now.timeIntervalSince1970]
        // Context is replaceable; only the latest cloud-change hint matters.
        try? WCSession.default.updateApplicationContext(hint)
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(hint, replyHandler: nil, errorHandler: { _ in })
        }
    }

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState,
                 error: (any Error)?) {
        if activationState == .activated, session.receivedApplicationContext[Self.hintKey] != nil {
            NotificationCenter.default.post(name: Self.refreshNotification, object: nil)
        }
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        if applicationContext[Self.hintKey] != nil {
            NotificationCenter.default.post(name: Self.refreshNotification, object: nil)
        }
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        if message[Self.hintKey] != nil {
            NotificationCenter.default.post(name: Self.refreshNotification, object: nil)
        }
    }

    #if os(iOS)
    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) { session.activate() }
    #endif
}

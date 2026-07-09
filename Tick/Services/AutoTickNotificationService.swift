import Foundation
import UserNotifications

@MainActor
protocol AutoTickNotificationSending {
    func requestAuthorizationIfNeeded() async
    func notifyAutoTickStarted(projectName: String, ruleName: String) async
    func notifyAutoTickStopped(projectName: String, ruleName: String) async
}

struct AutoTickNotificationService: AutoTickNotificationSending {
    private var isRunningTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    func requestAuthorizationIfNeeded() async {
        guard !isRunningTests else {
            return
        }

        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()

        guard settings.authorizationStatus == .notDetermined else {
            return
        }

        do {
            _ = try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            // Notification permission is best-effort. Tick should continue monitoring even if permission fails.
        }
    }

    func notifyAutoTickStarted(projectName: String, ruleName: String) async {
        await sendNotification(
            identifierPrefix: "auto-tick-started",
            title: "Auto Tick started",
            body: "\(projectName) started when you arrived at \(ruleName)."
        )
    }

    func notifyAutoTickStopped(projectName: String, ruleName: String) async {
        await sendNotification(
            identifierPrefix: "auto-tick-stopped",
            title: "Auto Tick stopped",
            body: "\(projectName) stopped when you left \(ruleName)."
        )
    }

    private func sendNotification(identifierPrefix: String, title: String, body: String) async {
        guard !isRunningTests else {
            return
        }

        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()

        guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else {
            return
        }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "\(identifierPrefix)-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )

        do {
            try await center.add(request)
        } catch {
            // Notification delivery is best-effort. Tick should never fail monitoring because of notification delivery.
        }
    }
}

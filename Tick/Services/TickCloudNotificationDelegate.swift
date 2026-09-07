import CloudKit
import UIKit
import OSLog

final class TickCloudNotificationDelegate: NSObject, UIApplicationDelegate {
    private let logger = Logger(subsystem: "dn.tick", category: "CloudPush")

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        application.registerForRemoteNotifications()
        return true
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        logger.error("Cloud notification registration failed")
    }

    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any],
                     fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        guard let notification = CKNotification(fromRemoteNotificationDictionary: userInfo),
              notification.subscriptionID == TickCloudKitTransport.subscriptionID else {
            completionHandler(.noData)
            return
        }
        logger.info("Cloud change notification received")
        Task {
            do {
                let changed = try await TickCloudSyncStore.shared.synchronize()
                NotificationCenter.default.post(name: .tickCloudSnapshotChanged, object: nil)
                completionHandler(changed ? .newData : .noData)
            } catch {
                completionHandler(.failed)
            }
        }
    }
}

extension Notification.Name {
    static let tickCloudSnapshotChanged = Notification.Name("tick.cloudSnapshotChanged")
}

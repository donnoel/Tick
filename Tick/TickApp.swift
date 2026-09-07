import SwiftUI

@main
struct TickApp: App {
    @UIApplicationDelegateAdaptor(TickCloudNotificationDelegate.self) private var cloudNotifications
    init() {
        if ProcessInfo.processInfo.arguments.contains("-resetDataForUITests") {
            TickSharedStorage.resetForUITests()
            TickUIStateStorage.resetForUITests()
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

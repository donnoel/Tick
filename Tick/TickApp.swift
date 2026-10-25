import SwiftUI

@main
struct TickApp: App {
    @UIApplicationDelegateAdaptor(TickCloudNotificationDelegate.self) private var cloudNotifications
    init() {
        if ProcessInfo.processInfo.arguments.contains("-resetDataForUITests") {
            TickSharedStorage.resetForUITests()
            TickUIStateStorage.resetForUITests()
#if UITEST_FIXTURES
            do {
                try TickUITestFixtureInstaller.installIfRequested()
            } catch {
                preconditionFailure("Could not install the requested UI-test fixture: \(error)")
            }
#endif
        }
        if !ProcessInfo.processInfo.arguments.contains("-disableCloudSyncForUITests") {
            TickWatchConnectivity.shared.activate()
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

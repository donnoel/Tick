import SwiftUI

@main
struct TickApp: App {
    init() {
        TickUIStateStorage.resetForNewAppLaunch()

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

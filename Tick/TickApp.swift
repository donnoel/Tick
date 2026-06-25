import SwiftUI

@main
struct TickApp: App {
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

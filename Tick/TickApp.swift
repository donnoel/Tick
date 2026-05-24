import SwiftUI

@main
struct TickApp: App {
    init() {
        if ProcessInfo.processInfo.arguments.contains("-resetDataForUITests") {
            TickSharedStorage.resetForUITests()
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

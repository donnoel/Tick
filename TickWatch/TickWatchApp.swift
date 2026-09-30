import AppIntents
import SwiftUI
import TickCore
import WatchKit

@main
struct TickWatchApp: App {
    @WKApplicationDelegateAdaptor(TickWatchAppDelegate.self) private var delegate

    var body: some Scene {
        WindowGroup { TickWatchView() }
    }
}

@MainActor
enum TickWatchServices {
    static let subscriptionID = "tick-watch-snapshot-v1"
    static let store: TickCloudClientStore = {
        #if targetEnvironment(simulator)
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-watchPreviewFixture") {
            return TickWatchPreview.store()
        }
        #endif
        return TickWatchPreview.unavailableStore()
        #else
        let environment = Bundle.main.object(forInfoDictionaryKey: "TickCloudEnvironment") as? String ?? "Development"
        let fileURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Tick/\(environment)/state.json")
        return TickCloudClientStore(
            transport: TickCloudKitTransport(subscriptionID: subscriptionID), fileURL: fileURL
        )
        #endif
    }()
}

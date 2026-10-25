import AppIntents
import WidgetKit

struct StartTickIntent: AppIntent {
    static let title: LocalizedStringResource = "Start Tick"
    static let description = IntentDescription("Start recording time for the default Tick space.")

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let invokedAt = Date.now
        _ = try? await TickCloudSyncStore.shared.synchronize()
        let result = try TickWidgetActionStore().startTick(at: invokedAt)
        WidgetCenter.shared.reloadAllTimelines()
        do { try await TickCloudSyncStore.shared.synchronize() }
        catch {
            return .result(dialog: IntentDialog(stringLiteral: result.message + " iCloud sync will retry."))
        }
        return .result(dialog: IntentDialog(stringLiteral: result.message))
    }
}

struct StopTickIntent: AppIntent {
    static let title: LocalizedStringResource = "Stop Tick"
    static let description = IntentDescription("Stop the active Tick session.")

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let invokedAt = Date.now
        let actionStore = TickWidgetActionStore()
        let tappedSessionID = try actionStore.loadStorageSnapshot().sessions.first(where: \.isActive)?.id
        _ = try? await TickCloudSyncStore.shared.synchronize()
        let result: TickWidgetActionResult
        if let tappedSessionID {
            result = try actionStore.stopTick(at: invokedAt, expectedSessionID: tappedSessionID)
        } else {
            result = TickWidgetActionResult(didChange: false, message: "No Tick is running.")
        }
        WidgetCenter.shared.reloadAllTimelines()
        do { try await TickCloudSyncStore.shared.synchronize() }
        catch {
            return .result(dialog: IntentDialog(stringLiteral: result.message + " iCloud sync will retry."))
        }
        return .result(dialog: IntentDialog(stringLiteral: result.message))
    }
}

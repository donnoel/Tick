import AppIntents
import WidgetKit

struct StartTickIntent: AppIntent {
    static let title: LocalizedStringResource = "Start Tick"
    static let description = IntentDescription("Start recording time for the default Tick space.")

    func perform() async throws -> some IntentResult & ProvidesDialog {
        _ = try? await TickCloudSyncStore.shared.synchronize()
        let result = try TickWidgetActionStore().startTick()
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
        _ = try? await TickCloudSyncStore.shared.synchronize()
        let result = try TickWidgetActionStore().stopTick()
        WidgetCenter.shared.reloadAllTimelines()
        do { try await TickCloudSyncStore.shared.synchronize() }
        catch {
            return .result(dialog: IntentDialog(stringLiteral: result.message + " iCloud sync will retry."))
        }
        return .result(dialog: IntentDialog(stringLiteral: result.message))
    }
}

import AppIntents
import WidgetKit

struct StartTickIntent: AppIntent {
    static var title: LocalizedStringResource = "Start Tick"
    static var description = IntentDescription("Start recording time for the default Tick space.")

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let result = try TickWidgetActionStore().startTick()
        WidgetCenter.shared.reloadAllTimelines()
        return .result(dialog: IntentDialog(stringLiteral: result.message))
    }
}

struct StopTickIntent: AppIntent {
    static var title: LocalizedStringResource = "Stop Tick"
    static var description = IntentDescription("Stop the active Tick session.")

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let result = try TickWidgetActionStore().stopTick()
        WidgetCenter.shared.reloadAllTimelines()
        return .result(dialog: IntentDialog(stringLiteral: result.message))
    }
}

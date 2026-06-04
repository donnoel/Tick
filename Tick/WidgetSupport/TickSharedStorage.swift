import Foundation

nonisolated enum TickSharedStorage {
    static let appGroupIdentifier = "group.dn.tick"
    static let dataFileName = "tick-data.json"
    static let widgetSnapshotFileName = "tick-widget-snapshot.json"
    static let voiceMemoMetadataFileName = "tick-voice-memos.json"
    static let voiceMemoDirectoryName = "VoiceMemos"

    static func dataFileURL(fileManager: FileManager = .default) -> URL {
        containerURL(fileManager: fileManager).appendingPathComponent(dataFileName)
    }

    static func legacyDataFileURL(fileManager: FileManager = .default) -> URL {
        applicationSupportContainerURL(fileManager: fileManager).appendingPathComponent(dataFileName)
    }

    static func widgetSnapshotFileURL(fileManager: FileManager = .default) -> URL {
        containerURL(fileManager: fileManager).appendingPathComponent(widgetSnapshotFileName)
    }

    static func voiceMemoMetadataFileURL(fileManager: FileManager = .default) -> URL {
        containerURL(fileManager: fileManager).appendingPathComponent(voiceMemoMetadataFileName)
    }

    static func voiceMemoDirectoryURL(fileManager: FileManager = .default) -> URL {
        containerURL(fileManager: fileManager).appendingPathComponent(voiceMemoDirectoryName, isDirectory: true)
    }

    /// UI-test only reset hook, enabled by `-resetDataForUITests`.
    static func resetForUITests(fileManager: FileManager = .default) {
        let currentDataURL = dataFileURL(fileManager: fileManager)
        let currentWidgetURL = widgetSnapshotFileURL(fileManager: fileManager)
        let voiceMemoMetadataURL = voiceMemoMetadataFileURL(fileManager: fileManager)
        let voiceMemoDirectoryURL = voiceMemoDirectoryURL(fileManager: fileManager)
        let legacyDataURL = legacyDataFileURL(fileManager: fileManager)

        try? fileManager.removeItem(at: currentDataURL)
        try? fileManager.removeItem(at: currentWidgetURL)
        try? fileManager.removeItem(at: voiceMemoMetadataURL)
        try? fileManager.removeItem(at: voiceMemoDirectoryURL)
        try? fileManager.removeItem(at: legacyDataURL)
    }

    private static func containerURL(fileManager: FileManager) -> URL {
        if let groupURL = fileManager.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) {
            return groupURL.appendingPathComponent("Tick", isDirectory: true)
        }

        return applicationSupportContainerURL(fileManager: fileManager)
    }

    private static func applicationSupportContainerURL(fileManager: FileManager) -> URL {
        fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Tick", isDirectory: true)
    }
}

import Foundation

nonisolated final class TickWidgetICloudSyncStore {
    private struct Envelope: Codable {
        var updatedAt: Date
        var snapshot: TickWidgetStorageSnapshot
    }

    private static let snapshotKey = "tick.storageSnapshot.v1"

    private let keyValueStore: TickKeyValueStore
    private let encoder: JSONEncoder

    init(keyValueStore: TickKeyValueStore = NSUbiquitousKeyValueStore.default) {
        self.keyValueStore = keyValueStore

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        self.encoder = encoder
    }

    func save(_ snapshot: TickWidgetStorageSnapshot, updatedAt: Date = .now) throws {
        let envelope = Envelope(updatedAt: updatedAt, snapshot: snapshot)
        let data = try encoder.encode(envelope)
        keyValueStore.set(data, forKey: Self.snapshotKey)
        keyValueStore.synchronize()
    }
}

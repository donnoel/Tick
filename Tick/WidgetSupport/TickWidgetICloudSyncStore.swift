import Foundation

nonisolated final class TickWidgetICloudSyncStore {
    private struct Envelope: Codable {
        var updatedAt: Date
        var snapshot: TickWidgetStorageSnapshot
    }

    static let snapshotKey = "tick.storageSnapshot.v1"

    private let keyValueStore: TickKeyValueStore
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    init(keyValueStore: TickKeyValueStore = NSUbiquitousKeyValueStore.default) {
        self.keyValueStore = keyValueStore

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        self.encoder = encoder
    }

    func loadEnvelope() throws -> (snapshot: TickWidgetStorageSnapshot, updatedAt: Date)? {
        keyValueStore.synchronize()

        guard let data = keyValueStore.data(forKey: Self.snapshotKey), !data.isEmpty else {
            return nil
        }

        let envelope = try decoder.decode(Envelope.self, from: data)
        return (envelope.snapshot, envelope.updatedAt)
    }

    func save(_ snapshot: TickWidgetStorageSnapshot, updatedAt: Date = .now) throws {
        let envelope = Envelope(updatedAt: updatedAt, snapshot: snapshot)
        let data = try encoder.encode(envelope)
        keyValueStore.set(data, forKey: Self.snapshotKey)
        keyValueStore.synchronize()
    }
}

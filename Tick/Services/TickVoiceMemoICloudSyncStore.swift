import Foundation

nonisolated final class TickVoiceMemoICloudSyncStore {
    private struct Envelope: Codable {
        var updatedAt: Date
        var snapshot: TickVoiceMemoStorageSnapshot
    }

    private static let snapshotKey = "tick.voiceMemoSnapshot.v1"

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

    func loadSnapshot() throws -> TickVoiceMemoStorageSnapshot? {
        keyValueStore.synchronize()

        guard let data = keyValueStore.data(forKey: Self.snapshotKey), !data.isEmpty else {
            return nil
        }

        return try decoder.decode(Envelope.self, from: data).snapshot
    }

    func save(_ snapshot: TickVoiceMemoStorageSnapshot, updatedAt: Date = .now) throws {
        let envelope = Envelope(updatedAt: updatedAt, snapshot: snapshot)
        let data = try encoder.encode(envelope)
        keyValueStore.set(data, forKey: Self.snapshotKey)
        keyValueStore.synchronize()
    }
}

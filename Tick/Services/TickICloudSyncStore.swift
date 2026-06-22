import Foundation

nonisolated struct TickICloudSyncResolution: Equatable {
    var snapshot: TickStorageSnapshot
    var shouldSaveLocal: Bool
    var shouldSaveRemote: Bool
}

nonisolated final class TickICloudSyncStore {
    private struct Envelope: Codable {
        var updatedAt: Date
        var snapshot: TickStorageSnapshot
    }

    private static let snapshotKey = "tick.storageSnapshot.v1"

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

    func loadEnvelope() throws -> (snapshot: TickStorageSnapshot, updatedAt: Date)? {
        keyValueStore.synchronize()

        guard let data = keyValueStore.data(forKey: Self.snapshotKey), !data.isEmpty else {
            return nil
        }

        let envelope = try decoder.decode(Envelope.self, from: data)
        return (envelope.snapshot, envelope.updatedAt)
    }

    func save(_ snapshot: TickStorageSnapshot, updatedAt: Date = .now) throws {
        let envelope = Envelope(updatedAt: updatedAt, snapshot: snapshot)
        let data = try encoder.encode(envelope)
        keyValueStore.set(data, forKey: Self.snapshotKey)
        keyValueStore.synchronize()
    }

    func resolve(
        localSnapshot: TickStorageSnapshot,
        localModifiedAt: Date?,
        remoteEnvelope: (snapshot: TickStorageSnapshot, updatedAt: Date)?
    ) -> TickICloudSyncResolution {
        guard let remoteEnvelope else {
            return TickICloudSyncResolution(
                snapshot: localSnapshot,
                shouldSaveLocal: false,
                shouldSaveRemote: !localSnapshot.isEmpty
            )
        }

        guard let localModifiedAt else {
            return TickICloudSyncResolution(
                snapshot: remoteEnvelope.snapshot,
                shouldSaveLocal: true,
                shouldSaveRemote: false
            )
        }

        if remoteEnvelope.updatedAt > localModifiedAt {
            return TickICloudSyncResolution(
                snapshot: remoteEnvelope.snapshot,
                shouldSaveLocal: true,
                shouldSaveRemote: false
            )
        }

        if localModifiedAt > remoteEnvelope.updatedAt, localSnapshot != remoteEnvelope.snapshot {
            return TickICloudSyncResolution(
                snapshot: localSnapshot,
                shouldSaveLocal: false,
                shouldSaveRemote: true
            )
        }

        return TickICloudSyncResolution(
            snapshot: localSnapshot,
            shouldSaveLocal: false,
            shouldSaveRemote: false
        )
    }
}

private extension TickStorageSnapshot {
    nonisolated var isEmpty: Bool {
        projects.isEmpty && sessions.isEmpty && autoTickRules.isEmpty
    }
}

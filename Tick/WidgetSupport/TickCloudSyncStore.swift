import Foundation
import OSLog
import WidgetKit

/// The local snapshot and its last server acknowledgment are one atomic file.
/// Their difference is the durable outbox, including edits made during an upload.
actor TickCloudSyncStore {
    nonisolated static let shared = TickCloudSyncStore()
    private let transport: any TickCloudTransport
    private let fileURL: URL
    private let widgetURL: URL
    private let importsLegacy: Bool
    private var flight: Task<Bool, Error>?
    private var subscribedAccount: String?
    private let logger = Logger(subsystem: "dn.tick", category: "CloudSync")

    init(transport: any TickCloudTransport = TickCloudKitTransport(),
         fileURL: URL = TickSharedStorage.dataFileURL(),
         widgetURL: URL = TickSharedStorage.widgetSnapshotFileURL(), importsLegacy: Bool = true) {
        self.transport = transport
        self.fileURL = fileURL
        self.widgetURL = widgetURL
        self.importsLegacy = importsLegacy
    }

    @discardableResult
    func synchronize() async throws -> Bool {
        if let flight { return try await flight.value }
        let task = Task { try await self.run() }
        flight = task
        defer { flight = nil }
        return try await task.value
    }

    private func run() async throws -> Bool {
        let correlation = UUID().uuidString
        var phase = "account"
        logger.info("Sync began id=\(correlation, privacy: .public)")
        do {
            let account = try await transport.accountID()
            try bind(account: account)
            var changed = false
            for _ in 0..<4 {
                phase = "fetch"
                let remote = try await transport.fetch()
                let local = try read()
                guard local.cloudSync?.accountID == account else { throw TickCloudError.accountChanged }
                guard remote != nil || local.cloudSync?.acknowledged == nil else {
                    throw TickCloudError.invalidRecord
                }
                let merged = TickCloudMerge.resolve(
                    base: local.cloudSync?.acknowledged?.snapshot ?? migrationBase(local: local.snapshot, remote: remote?.payload.snapshot),
                    local: local.snapshot,
                    remote: remote?.payload ?? TickCloudPayload(snapshot: .empty)
                )
                let saved: TickCloudRemote
                do {
                    if let remote, remote.payload == merged {
                        saved = remote
                    } else {
                        phase = "save"
                        saved = try await transport.save(merged, version: remote?.version)
                    }
                } catch TickCloudError.conflict {
                    continue
                }
                guard try await transport.accountID() == account else { throw TickCloudError.accountChanged }
                let applied = try acknowledge(saved.payload, submitted: local.snapshot, account: account)
                changed = changed || applied.changed
                logger.info("Sync acknowledged id=\(correlation, privacy: .public) pending=\(applied.pending) active=\(saved.payload.snapshot.sessions.filter(\.isActive).count)")
                if !applied.pending {
                    // Create the record type before its first subscription in a fresh development container.
                    if Bundle.main.bundleURL.pathExtension != "appex", subscribedAccount != account {
                        phase = "subscribe"
                        try await transport.subscribe()
                        subscribedAccount = account
                    }
                    return changed
                }
            }
            throw TickCloudError.busy
        } catch {
            logger.error("Sync deferred id=\(correlation, privacy: .public) phase=\(phase, privacy: .public) error=\(TickCloudFailure.diagnostic(error), privacy: .public)")
            throw error
        }
    }

    private typealias Envelope = TickStorageFileEnvelope<TickWidgetStorageSnapshot>

    private func migrationBase(local: TickWidgetStorageSnapshot,
                               remote: TickWidgetStorageSnapshot?) -> TickWidgetStorageSnapshot {
        guard let remote else { return .empty }
        // On a second device, import missing history without overwriting records
        // already migrated by the first device. Terminal Stop still wins in merge.
        return TickWidgetStorageSnapshot(
            projects: local.projects.filter { value in remote.projects.contains { $0.id == value.id } },
            sessions: local.sessions.filter { value in remote.sessions.contains { $0.id == value.id } },
            autoTickRules: local.autoTickRules.filter { value in remote.autoTickRules.contains { $0.id == value.id } }
        )
    }

    private func read() throws -> Envelope {
        try TickSharedFileCoordinator.coordinateReading(at: fileURL) { try readUncoordinated($0) }
    }

    private func readUncoordinated(_ url: URL) throws -> Envelope {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return Envelope(updatedAt: .distantPast, snapshot: .empty)
        }
        let data = try Data(contentsOf: url)
        if let envelope = try? TickCloudCodec.decode(Envelope.self, from: data) { return envelope }
        let snapshot = try TickCloudCodec.decode(TickWidgetStorageSnapshot.self, from: data)
        let date = try FileManager.default.attributesOfItem(atPath: url.path)[.modificationDate] as? Date
        return Envelope(updatedAt: date ?? .distantPast, snapshot: snapshot)
    }

    private func bind(account: String) throws {
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try TickSharedFileCoordinator.coordinateWriting(at: fileURL) { url in
            var state = try readUncoordinated(url)
            if let checkpoint = state.cloudSync {
                guard checkpoint.accountID == account else { throw TickCloudError.accountChanged }
                return
            }
            let backupURL = url.appendingPathExtension("pre-cloudkit")
            if FileManager.default.fileExists(atPath: url.path),
               !FileManager.default.fileExists(atPath: backupURL.path) {
                try Data(contentsOf: url).write(to: backupURL, options: .atomic)
            }
            // One-way import. New builds never publish timer snapshots back to KVS.
            if importsLegacy, let legacy = try TickWidgetICloudSyncStore().loadEnvelope(),
               legacy.updatedAt > state.updatedAt {
                state.snapshot = legacy.snapshot
                state.updatedAt = legacy.updatedAt
            }
            state.cloudSync = TickCloudCheckpoint(accountID: account)
            try TickCloudCodec.encode(state).write(to: url, options: .atomic)
        }
    }

    private func acknowledge(_ payload: TickCloudPayload, submitted: TickWidgetStorageSnapshot,
                             account: String) throws -> (changed: Bool, pending: Bool) {
        try TickSharedFileCoordinator.coordinateWriting(at: fileURL) { url in
            let latest = try readUncoordinated(url)
            guard latest.cloudSync?.accountID == account else { throw TickCloudError.accountChanged }
            let resolved = TickCloudMerge.resolve(base: submitted, local: latest.snapshot, remote: payload)
            let changed = resolved.snapshot != latest.snapshot
            let state = Envelope(updatedAt: changed ? .now : latest.updatedAt, snapshot: resolved.snapshot,
                                 cloudSync: TickCloudCheckpoint(accountID: account, acknowledged: payload, confirmedAt: .now))
            try TickCloudCodec.encode(state).write(to: url, options: .atomic)
            // Preserve the user's selected widget space while committing the remote state.
            let store = TickWidgetActionStore(dataFileURL: fileURL, widgetSnapshotFileURL: widgetURL)
            let cached = try? Data(contentsOf: widgetURL)
            let selected = cached.flatMap { try? TickCloudCodec.decode(TickWidgetSnapshot.self, from: $0) }?.defaultProjectID
            try store.saveWidgetSnapshot(TickWidgetSnapshotBuilder.snapshot(from: resolved.snapshot, defaultProjectID: selected))
            if changed { WidgetCenter.shared.reloadAllTimelines() }
            return (changed, resolved != payload)
        }
    }
}

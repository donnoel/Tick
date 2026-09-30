import CloudKit
import Foundation

/// A device's cache and server acknowledgment are saved together. The difference
/// is its durable outbox; devices never share a local file across platforms.
nonisolated public struct TickCloudClientState: Codable, Sendable {
    public var snapshot: TickWidgetStorageSnapshot
    public var checkpoint: TickCloudCheckpoint?

    public init(snapshot: TickWidgetStorageSnapshot = .empty, checkpoint: TickCloudCheckpoint? = nil) {
        self.snapshot = snapshot
        self.checkpoint = checkpoint
    }

    public var canRecord: Bool { checkpoint?.acknowledged != nil }
    public var hasPendingChanges: Bool {
        guard let acknowledged = checkpoint?.acknowledged else { return false }
        return snapshot != acknowledged.snapshot
    }
}

nonisolated public enum TickCloudClientAction: Sendable {
    case start(projectID: UUID, sessionID: UUID, at: Date)
    case pause(sessionID: UUID, at: Date)
    case resume(sessionID: UUID, at: Date)
    case stop(sessionID: UUID, at: Date)
}

public actor TickCloudClientStore {
    private let transport: any TickCloudTransport
    private let fileURL: URL
    private var flight: Task<TickCloudClientState, Error>?
    private var subscribedAccount: String?

    public init(transport: any TickCloudTransport, fileURL: URL) {
        self.transport = transport
        self.fileURL = fileURL
    }

    public func load() throws -> TickCloudClientState {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return TickCloudClientState() }
        do { return try TickCloudCodec.decode(TickCloudClientState.self, from: Data(contentsOf: fileURL)) }
        catch is DecodingError { throw Failure.unreadableCache }
    }

    private func save(_ state: TickCloudClientState) throws {
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try TickCloudCodec.encode(state).write(to: fileURL, options: .atomic)
    }

    public func refresh() async throws -> TickCloudClientState {
        if let flight { return try await flight.value }
        let task = Task { try await self.synchronize() }
        flight = task
        defer { flight = nil }
        return try await task.value
    }

    /// Capture the tap's date and displayed session ID before refreshing. Only a
    /// previously account-bound cache can record through a temporary outage.
    public func perform(_ action: TickCloudClientAction) async throws -> TickCloudClientState {
        do { _ = try await refresh() }
        catch {
            guard Self.isTemporaryCloudFailure(error), try load().canRecord else { throw error }
        }
        var state = try load()
        guard state.canRecord else { throw Failure.needsFirstSync }
        switch action {
        case let .start(projectID, sessionID, date):
            try TickTimerMutation.start(in: &state.snapshot, projectID: projectID, sessionID: sessionID, at: date)
        case let .pause(sessionID, date):
            try TickTimerMutation.pause(in: &state.snapshot, sessionID: sessionID, at: date)
        case let .resume(sessionID, date):
            try TickTimerMutation.resume(in: &state.snapshot, sessionID: sessionID, at: date)
        case let .stop(sessionID, date):
            try TickTimerMutation.stop(in: &state.snapshot, sessionID: sessionID, at: date)
        }
        try save(state)
        return state
    }

    private func synchronize() async throws -> TickCloudClientState {
        let account = try await transport.accountID()
        if let bound = try load().checkpoint?.accountID, bound != account { throw TickCloudError.accountChanged }
        for _ in 0..<4 {
            let remote = try await transport.fetch()
            let local = try load()
            if let bound = local.checkpoint?.accountID, bound != account { throw TickCloudError.accountChanged }
            guard let remote else {
                guard local.checkpoint?.acknowledged == nil else { throw TickCloudError.invalidRecord }
                // Joining an empty cloud account never publishes an empty cache.
                return local
            }
            let merged = TickCloudMerge.resolve(base: local.checkpoint?.acknowledged?.snapshot ?? .empty,
                                               local: local.snapshot, remote: remote.payload)
            let saved: TickCloudRemote
            do {
                saved = merged == remote.payload ? remote : try await transport.save(merged, version: remote.version)
            } catch TickCloudError.conflict { continue }
            guard try await transport.accountID() == account else { throw TickCloudError.accountChanged }
            let latest = try load()
            let resolved = TickCloudMerge.resolve(base: local.snapshot, local: latest.snapshot, remote: saved.payload)
            let state = TickCloudClientState(snapshot: resolved.snapshot, checkpoint: TickCloudCheckpoint(
                accountID: account, acknowledged: saved.payload, confirmedAt: .now
            ))
            try save(state)
            if !state.hasPendingChanges {
                if subscribedAccount != account {
                    try await transport.subscribe()
                    subscribedAccount = account
                }
                return state
            }
        }
        throw TickCloudError.busy
    }

    nonisolated public static func isTemporaryCloudFailure(_ error: Error) -> Bool {
        if let error = error as? TickCloudError {
            switch error {
            case .busy, .conflict: return true
            case .accountChanged, .invalidRecord: return false
            }
        }
        guard let error = error as? CKError else { return false }
        return [.networkUnavailable, .networkFailure, .serviceUnavailable, .requestRateLimited, .zoneBusy]
            .contains(error.code)
    }

    nonisolated public enum Failure: LocalizedError {
        case needsFirstSync
        case unreadableCache

        public var errorDescription: String? {
            switch self {
            case .needsFirstSync: "Connect to iCloud and load your Spaces before starting a Tick."
            case .unreadableCache: "Tick couldn't read its saved data. Your local file has been preserved."
            }
        }
    }
}

import Foundation

private enum TickDataStoreError: LocalizedError {
    case corruptDataPreserved(URL)
    case concurrentActiveSessions
    case concurrentSpaceChange

    var errorDescription: String? {
        switch self {
        case .corruptDataPreserved(let backupURL):
            "Saved time could not be read. The original file was preserved as \(backupURL.lastPathComponent). Please contact support before adding more time."
        case .concurrentActiveSessions:
            "Two Ticks are already active, or this Space has an active Tick. Reload before starting another."
        case .concurrentSpaceChange:
            "A Space changed on another device or widget. Reload before saving this change."
        }
    }
}

actor TickDataStore {
    private let fileURL: URL
    private let legacyFileURL: URL?
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder
    private let fileManager: FileManager

    init(fileURL: URL? = nil, fileManager: FileManager = .default) {
        self.fileManager = fileManager
        self.fileURL = fileURL ?? TickSharedStorage.dataFileURL(fileManager: fileManager)
        self.legacyFileURL = fileURL == nil ? TickSharedStorage.legacyDataFileURL(fileManager: fileManager) : nil

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.encoder = encoder
    }

    func load() throws -> TickStorageSnapshot {
        try loadVersionedSnapshot().snapshot
    }

    func boundCloudAccountID() throws -> String? {
        try TickSharedFileCoordinator.coordinateReading(at: fileURL) { coordinatedURL in
            guard fileManager.fileExists(atPath: coordinatedURL.path) else { return nil }
            let data = try Data(contentsOf: coordinatedURL)
            return try decoder.decode(
                TickStorageFileEnvelope<TickStorageSnapshot>.self, from: data
            ).cloudSync?.accountID
        }
    }

    func runningStateConfirmationDate() -> Date? {
        try? TickWidgetActionStore(dataFileURL: fileURL, widgetSnapshotFileURL: fileURL).runningStateConfirmationDate()
    }

    func loadVersionedSnapshot() throws -> (snapshot: TickStorageSnapshot, updatedAt: Date?) {
        try migrateLegacyStoreIfNeeded()

        guard fileManager.fileExists(atPath: fileURL.path) else {
            return (.empty, nil)
        }

        let storedData = try TickSharedFileCoordinator.coordinateReading(at: fileURL) { coordinatedURL in
            let data = try Data(contentsOf: coordinatedURL)
            let attributes = try fileManager.attributesOfItem(atPath: coordinatedURL.path)
            return (data, attributes[.modificationDate] as? Date)
        }

        guard !storedData.0.isEmpty else {
            return (.empty, storedData.1)
        }

        do {
            return try decodeSnapshot(storedData.0, fallbackUpdatedAt: storedData.1)
        } catch {
            let backupURL = try recoverCorruptStore()
            throw TickDataStoreError.corruptDataPreserved(backupURL)
        }
    }

    func mergeAndSave(
        base: TickStorageSnapshot,
        proposed: TickStorageSnapshot,
        updatedAt: Date = .now
    ) throws -> TickStorageSnapshot {
        try fileManager.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        return try TickSharedFileCoordinator.coordinateWriting(at: fileURL) { coordinatedURL in
            let existing = fileManager.fileExists(atPath: coordinatedURL.path)
                ? try Data(contentsOf: coordinatedURL) : Data()
            let latest = existing.isEmpty ? .empty : try decodeSnapshot(existing, fallbackUpdatedAt: nil).snapshot
            let checkpoint = existing.isEmpty ? nil :
                (try? decoder.decode(TickStorageFileEnvelope<TickStorageSnapshot>.self, from: existing).cloudSync)
            let merged = TickStorageSnapshot.mergingEdits(base: base, proposed: proposed, latest: latest)
            let activeSessions = merged.sessions.filter(\.isActive)
            guard activeSessions.count <= 2,
                  Set(activeSessions.map(\.projectID)).count == activeSessions.count else {
                throw TickDataStoreError.concurrentActiveSessions
            }
            let projectIDs = Set(merged.projects.map(\.id))
            let editedSessionIDs = Set(proposed.sessions.filter { session in
                base.sessions.first(where: { $0.id == session.id }) != session
            }.map(\.id))
            let deletedProjectIDs = Set(base.projects.map(\.id))
                .subtracting(proposed.projects.map(\.id))
            guard merged.sessions.allSatisfy({ session in
                if editedSessionIDs.contains(session.id) || deletedProjectIDs.contains(session.projectID) {
                    return projectIDs.contains(session.projectID)
                }
                return true
            }) else {
                throw TickDataStoreError.concurrentSpaceChange
            }
            let data = try encoder.encode(
                TickStorageFileEnvelope(updatedAt: updatedAt, snapshot: merged, cloudSync: checkpoint)
            )
            // Match the dates the next read will decode (ISO 8601 drops subsecond precision).
            let storedSnapshot = try decoder.decode(
                TickStorageFileEnvelope<TickStorageSnapshot>.self, from: data
            ).snapshot
            try data.write(to: coordinatedURL, options: [.atomic])
            return storedSnapshot
        }
    }

    func save(_ snapshot: TickStorageSnapshot, updatedAt: Date = .now) throws {
        let directoryURL = fileURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)

        try TickSharedFileCoordinator.coordinateWriting(at: fileURL) { coordinatedURL in
            let existing = fileManager.fileExists(atPath: coordinatedURL.path)
                ? try Data(contentsOf: coordinatedURL) : Data()
            if !existing.isEmpty {
                _ = try decodeSnapshot(existing, fallbackUpdatedAt: nil)
            }
            let checkpoint = try? decoder.decode(
                TickStorageFileEnvelope<TickStorageSnapshot>.self, from: existing
            ).cloudSync
            let data = try encoder.encode(
                TickStorageFileEnvelope(updatedAt: updatedAt, snapshot: snapshot, cloudSync: checkpoint)
            )
            try data.write(to: coordinatedURL, options: [.atomic])
        }
    }

    private func migrateLegacyStoreIfNeeded() throws {
        guard let legacyFileURL,
              legacyFileURL != fileURL,
              !fileManager.fileExists(atPath: fileURL.path),
              fileManager.fileExists(atPath: legacyFileURL.path) else {
            return
        }

        try fileManager.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try fileManager.copyItem(at: legacyFileURL, to: fileURL)
    }

    private func decodeSnapshot(
        _ data: Data,
        fallbackUpdatedAt: Date?
    ) throws -> (snapshot: TickStorageSnapshot, updatedAt: Date?) {
        if try TickStorageFileEnvelope<TickStorageSnapshot>.hasEnvelopeShape(data) {
            let envelope = try decoder.decode(TickStorageFileEnvelope<TickStorageSnapshot>.self, from: data)
            return (envelope.snapshot, envelope.updatedAt)
        }
        return (try decoder.decode(TickStorageSnapshot.self, from: data), fallbackUpdatedAt)
    }

    private func recoverCorruptStore() throws -> URL {
        let backupURL = corruptBackupFileURL()

        try TickSharedFileCoordinator.coordinateWriting(at: fileURL) { coordinatedURL in
            try fileManager.copyItem(at: coordinatedURL, to: backupURL)
        }

        return backupURL
    }

    private func corruptBackupFileURL() -> URL {
        let directoryURL = fileURL.deletingLastPathComponent()
        let baseName = fileURL.deletingPathExtension().lastPathComponent
        let fileExtension = fileURL.pathExtension
        let timestamp = Int(Date().timeIntervalSince1970)
        let backupName = "\(baseName).corrupt-\(timestamp)-\(UUID().uuidString).\(fileExtension)"

        return directoryURL.appendingPathComponent(backupName)
    }
}

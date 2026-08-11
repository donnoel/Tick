import Foundation

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
            if let envelope = try? decoder.decode(
                TickStorageFileEnvelope<TickStorageSnapshot>.self,
                from: storedData.0
            ) {
                return (envelope.snapshot, envelope.updatedAt)
            }

            return (try decoder.decode(TickStorageSnapshot.self, from: storedData.0), storedData.1)
        } catch {
            return (try recoverCorruptStore(), nil)
        }
    }

    func save(_ snapshot: TickStorageSnapshot, updatedAt: Date = .now) throws {
        let directoryURL = fileURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)

        let data = try encoder.encode(
            TickStorageFileEnvelope(updatedAt: updatedAt, snapshot: snapshot)
        )
        try TickSharedFileCoordinator.coordinateWriting(at: fileURL) { coordinatedURL in
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

    private func recoverCorruptStore() throws -> TickStorageSnapshot {
        let backupURL = corruptBackupFileURL()

        try TickSharedFileCoordinator.coordinateWriting(at: fileURL) { coordinatedURL in
            try fileManager.moveItem(at: coordinatedURL, to: backupURL)
        }

        return .empty
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

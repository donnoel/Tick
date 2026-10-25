import Foundation

nonisolated struct TickVoiceMemoStorageSnapshot: Codable, Equatable {
    var voiceMemos: [VoiceMemo]
    var deletedVoiceMemos: [VoiceMemoDeletion]

    static let empty = TickVoiceMemoStorageSnapshot(voiceMemos: [], deletedVoiceMemos: [])

    init(voiceMemos: [VoiceMemo], deletedVoiceMemos: [VoiceMemoDeletion] = []) {
        self.voiceMemos = voiceMemos
        self.deletedVoiceMemos = deletedVoiceMemos
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        voiceMemos = try container.decodeIfPresent([VoiceMemo].self, forKey: .voiceMemos) ?? []
        deletedVoiceMemos = try container.decodeIfPresent([VoiceMemoDeletion].self, forKey: .deletedVoiceMemos) ?? []
    }
}

extension TickVoiceMemoStorageSnapshot {
    nonisolated var isEmpty: Bool {
        voiceMemos.isEmpty && deletedVoiceMemos.isEmpty
    }
}

actor TickVoiceMemoStore {
    enum AccountError: LocalizedError {
        case unverified
        case changed

        var errorDescription: String? {
            switch self {
            case .unverified:
                "Verify the current iCloud account before using voice memos. Existing recordings are preserved."
            case .changed:
                "The iCloud account changed. Voice memos are paused so recordings from another account stay separate."
            }
        }
    }

    private let localMetadataFileURL: URL
    private let localVoiceMemoDirectoryURL: URL
    private let iCloudMetadataFileURL: URL?
    private let iCloudVoiceMemoDirectoryURL: URL?
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder
    private let fileManager: FileManager
    private let requiresAccountBinding: Bool
    private var verifiedAccountID: String?
    private var syncDeferred = false
    private var cloudReadable = true

    init(
        metadataFileURL: URL? = nil,
        voiceMemoDirectoryURL: URL? = nil,
        iCloudMetadataFileURL: URL? = nil,
        iCloudVoiceMemoDirectoryURL: URL? = nil,
        usesICloud: Bool = true,
        requiresAccountBinding: Bool? = nil,
        fileManager: FileManager = .default
    ) {
        self.fileManager = fileManager
        self.localMetadataFileURL = metadataFileURL ?? TickSharedStorage.voiceMemoMetadataFileURL(fileManager: fileManager)
        self.localVoiceMemoDirectoryURL = voiceMemoDirectoryURL ?? TickSharedStorage.voiceMemoDirectoryURL(fileManager: fileManager)
        self.iCloudMetadataFileURL = iCloudMetadataFileURL ?? (usesICloud ? TickSharedStorage.iCloudVoiceMemoMetadataFileURL(fileManager: fileManager) : nil)
        self.iCloudVoiceMemoDirectoryURL = iCloudVoiceMemoDirectoryURL ?? (usesICloud ? TickSharedStorage.iCloudVoiceMemoDirectoryURL(fileManager: fileManager) : nil)
        self.requiresAccountBinding = requiresAccountBinding ?? (metadataFileURL == nil && usesICloud)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.encoder = encoder
    }

    func bind(to accountID: String, trustedLegacyAccountID: String?) throws {
        guard requiresAccountBinding else { return }
        let ownerURL = localMetadataFileURL.appendingPathExtension("account")
        if fileManager.fileExists(atPath: ownerURL.path) {
            let storedID = try String(contentsOf: ownerURL, encoding: .utf8)
            guard storedID == accountID else {
                verifiedAccountID = nil
                throw AccountError.changed
            }
        } else {
            let hasLocalMetadata: Bool
            if fileManager.fileExists(atPath: localMetadataFileURL.path) {
                let attributes = try fileManager.attributesOfItem(atPath: localMetadataFileURL.path)
                hasLocalMetadata = (attributes[.size] as? Int ?? 0) > 0
            } else {
                hasLocalMetadata = false
            }
            guard !hasLocalMetadata || trustedLegacyAccountID == accountID else {
                verifiedAccountID = nil
                throw AccountError.unverified
            }
            try fileManager.createDirectory(at: ownerURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try accountID.write(to: ownerURL, atomically: true, encoding: .utf8)
        }
        verifiedAccountID = accountID
    }

    func invalidateAccount() {
        verifiedAccountID = nil
    }

    func hasDeferredSync() -> Bool { syncDeferred }

    private func requireVerifiedAccount() throws {
        guard !requiresAccountBinding || verifiedAccountID != nil else {
            throw AccountError.unverified
        }
    }

    func load() throws -> [VoiceMemo] {
        let snapshot = try loadSnapshot()
        return snapshot.voiceMemos
    }

    func saveLocalOnly(_ voiceMemos: [VoiceMemo]) throws {
        try requireVerifiedAccount()
        let existing = try loadSnapshot(at: localMetadataFileURL)
        let merged = Self.merged(existing, TickVoiceMemoStorageSnapshot(voiceMemos: voiceMemos))
        try write(merged, to: localMetadataFileURL)
        syncDeferred = true
    }

    func loadSnapshot() throws -> TickVoiceMemoStorageSnapshot {
        try requireVerifiedAccount()
        let snapshot = try resolvedSnapshot()
        try persistAndSync(snapshot)
        return snapshot
    }

    @discardableResult
    func save(
        _ voiceMemos: [VoiceMemo],
        deletedVoiceMemoIDs: [VoiceMemo.ID] = [],
        deletedAt: Date = .now,
        audioFileNamesToSync: Set<String>? = nil
    ) throws -> TickVoiceMemoStorageSnapshot {
        try requireVerifiedAccount()
        var snapshot = try resolvedSnapshot()
        let incomingSnapshot = TickVoiceMemoStorageSnapshot(
            voiceMemos: voiceMemos,
            deletedVoiceMemos: deletedVoiceMemoIDs.map { deletedVoiceMemoID in
                VoiceMemoDeletion(
                    id: deletedVoiceMemoID,
                    fileName: fileName(for: deletedVoiceMemoID, in: snapshot.voiceMemos + voiceMemos),
                    deletedAt: deletedAt
                )
            }
        )
        snapshot = Self.merged(snapshot, incomingSnapshot)
        try persistAndSync(snapshot, fileNames: audioFileNamesToSync)
        return snapshot
    }

    @discardableResult
    func save(
        _ snapshot: TickVoiceMemoStorageSnapshot,
        audioFileNamesToSync: Set<String>? = nil
    ) throws -> TickVoiceMemoStorageSnapshot {
        try requireVerifiedAccount()
        let mergedSnapshot = Self.merged(try resolvedSnapshot(), snapshot)
        try persistAndSync(mergedSnapshot, fileNames: audioFileNamesToSync)
        return mergedSnapshot
    }

    func preparedFileURL(for fileName: String) throws -> URL {
        try requireVerifiedAccount()
        try fileManager.createDirectory(at: localVoiceMemoDirectoryURL, withIntermediateDirectories: true)
        return fileURL(for: fileName)
    }

    func fileURL(for fileName: String) -> URL {
        localVoiceMemoDirectoryURL.appendingPathComponent(fileName)
    }

    func deleteAudioFile(for voiceMemo: VoiceMemo) throws {
        let localFileURL = fileURL(for: voiceMemo.fileName)

        if fileManager.fileExists(atPath: localFileURL.path) {
            try fileManager.removeItem(at: localFileURL)
        }

        if let iCloudFileURL = iCloudVoiceMemoDirectoryURL?.appendingPathComponent(voiceMemo.fileName),
           fileManager.fileExists(atPath: iCloudFileURL.path) {
            try fileManager.removeItem(at: iCloudFileURL)
        }
    }

    func deleteAudioFiles(for voiceMemos: [VoiceMemo]) throws {
        for voiceMemo in voiceMemos {
            try deleteAudioFile(for: voiceMemo)
        }
    }

    private func resolvedSnapshot() throws -> TickVoiceMemoStorageSnapshot {
        let local = try loadSnapshot(at: localMetadataFileURL)
        guard let iCloudMetadataFileURL else {
            cloudReadable = true
            return local
        }
        do {
            let remote = try loadSnapshot(at: iCloudMetadataFileURL)
            cloudReadable = true
            return Self.merged(local, remote)
        } catch {
            cloudReadable = false
            syncDeferred = true
            return local
        }
    }

    private func loadSnapshot(at fileURL: URL) throws -> TickVoiceMemoStorageSnapshot {
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return .empty
        }

        let data = try Data(contentsOf: fileURL)

        guard !data.isEmpty else {
            return .empty
        }

        if let snapshot = try? decoder.decode(TickVoiceMemoStorageSnapshot.self, from: data) {
            return snapshot
        }

        return TickVoiceMemoStorageSnapshot(voiceMemos: try decoder.decode([VoiceMemo].self, from: data))
    }

    private func persistAndSync(
        _ snapshot: TickVoiceMemoStorageSnapshot,
        fileNames: Set<String>? = nil
    ) throws {
        try write(snapshot, to: localMetadataFileURL)
        guard cloudReadable else {
            syncDeferred = true
            return
        }
        do {
            if let iCloudMetadataFileURL {
                try write(snapshot, to: iCloudMetadataFileURL)
            }
            try syncAudioFiles(for: snapshot.voiceMemos, fileNames: fileNames)
            try deleteAudioFiles(for: snapshot.deletedVoiceMemos)
            syncDeferred = false
        } catch {
            // Local metadata is durable. Keep audio until cloud metadata catches up.
            syncDeferred = true
        }
    }

    private func write(_ snapshot: TickVoiceMemoStorageSnapshot, to fileURL: URL) throws {
        let directoryURL = fileURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)

        let data = try encoder.encode(snapshot)
        try data.write(to: fileURL, options: [.atomic])
    }

    private func syncAudioFiles(for voiceMemos: [VoiceMemo], fileNames: Set<String>? = nil) throws {
        guard let iCloudVoiceMemoDirectoryURL,
              fileNames?.isEmpty != true else {
            return
        }

        let voiceMemosToSync = fileNames.map { names in
            voiceMemos.filter { names.contains($0.fileName) }
        } ?? voiceMemos

        guard !voiceMemosToSync.isEmpty else {
            return
        }

        try fileManager.createDirectory(at: localVoiceMemoDirectoryURL, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: iCloudVoiceMemoDirectoryURL, withIntermediateDirectories: true)

        for voiceMemo in voiceMemosToSync {
            let localFileURL = fileURL(for: voiceMemo.fileName)
            let iCloudFileURL = iCloudVoiceMemoDirectoryURL.appendingPathComponent(voiceMemo.fileName)
            let localExists = fileManager.fileExists(atPath: localFileURL.path)
            let iCloudExists = fileManager.fileExists(atPath: iCloudFileURL.path)

            if localExists && !iCloudExists {
                try fileManager.copyItem(at: localFileURL, to: iCloudFileURL)
            } else if iCloudExists && !localExists {
                try fileManager.copyItem(at: iCloudFileURL, to: localFileURL)
            }
        }
    }

    private func deleteAudioFiles(for deletedVoiceMemos: [VoiceMemoDeletion]) throws {
        for deletedVoiceMemo in deletedVoiceMemos {
            guard let fileName = deletedVoiceMemo.fileName else {
                continue
            }

            let localFileURL = fileURL(for: fileName)
            if fileManager.fileExists(atPath: localFileURL.path) {
                try fileManager.removeItem(at: localFileURL)
            }

            if let iCloudFileURL = iCloudVoiceMemoDirectoryURL?.appendingPathComponent(fileName),
               fileManager.fileExists(atPath: iCloudFileURL.path) {
                try fileManager.removeItem(at: iCloudFileURL)
            }
        }
    }

    private func fileName(for voiceMemoID: VoiceMemo.ID, in voiceMemos: [VoiceMemo]) -> String? {
        voiceMemos.first { $0.id == voiceMemoID }?.fileName
    }

    static func merged(
        _ lhs: TickVoiceMemoStorageSnapshot,
        _ rhs: TickVoiceMemoStorageSnapshot
    ) -> TickVoiceMemoStorageSnapshot {
        let deletedVoiceMemos = latestDeletions(lhs.deletedVoiceMemos + rhs.deletedVoiceMemos)
        let deletionByID = Dictionary(uniqueKeysWithValues: deletedVoiceMemos.map { ($0.id, $0) })
        let voiceMemos = latestVoiceMemos(lhs.voiceMemos + rhs.voiceMemos, deletionByID: deletionByID)

        return TickVoiceMemoStorageSnapshot(
            voiceMemos: voiceMemos.sorted { $0.createdAt > $1.createdAt },
            deletedVoiceMemos: deletedVoiceMemos.sorted { $0.deletedAt > $1.deletedAt }
        )
    }

    private static func latestDeletions(_ deletions: [VoiceMemoDeletion]) -> [VoiceMemoDeletion] {
        var deletionByID: [VoiceMemo.ID: VoiceMemoDeletion] = [:]

        for deletion in deletions {
            if let existingDeletion = deletionByID[deletion.id],
               existingDeletion.deletedAt >= deletion.deletedAt {
                continue
            }

            deletionByID[deletion.id] = deletion
        }

        return Array(deletionByID.values)
    }

    private static func latestVoiceMemos(
        _ voiceMemos: [VoiceMemo],
        deletionByID: [VoiceMemo.ID: VoiceMemoDeletion]
    ) -> [VoiceMemo] {
        var voiceMemoByID: [VoiceMemo.ID: VoiceMemo] = [:]

        for voiceMemo in voiceMemos {
            if let deletion = deletionByID[voiceMemo.id],
               deletion.deletedAt >= voiceMemo.updatedAt {
                continue
            }

            if let existingVoiceMemo = voiceMemoByID[voiceMemo.id],
               existingVoiceMemo.updatedAt >= voiceMemo.updatedAt {
                continue
            }

            voiceMemoByID[voiceMemo.id] = voiceMemo
        }

        return Array(voiceMemoByID.values)
    }
}

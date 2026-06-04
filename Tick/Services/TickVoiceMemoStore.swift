import Foundation

actor TickVoiceMemoStore {
    private let metadataFileURL: URL
    private let voiceMemoDirectoryURL: URL
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder
    private let fileManager: FileManager

    init(
        metadataFileURL: URL? = nil,
        voiceMemoDirectoryURL: URL? = nil,
        fileManager: FileManager = .default
    ) {
        self.fileManager = fileManager
        self.metadataFileURL = metadataFileURL ?? TickSharedStorage.voiceMemoMetadataFileURL(fileManager: fileManager)
        self.voiceMemoDirectoryURL = voiceMemoDirectoryURL ?? TickSharedStorage.voiceMemoDirectoryURL(fileManager: fileManager)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.encoder = encoder
    }

    func load() throws -> [VoiceMemo] {
        guard fileManager.fileExists(atPath: metadataFileURL.path) else {
            return []
        }

        let data = try Data(contentsOf: metadataFileURL)

        guard !data.isEmpty else {
            return []
        }

        return try decoder.decode([VoiceMemo].self, from: data)
    }

    func save(_ voiceMemos: [VoiceMemo]) throws {
        let directoryURL = metadataFileURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)

        let data = try encoder.encode(voiceMemos)
        try data.write(to: metadataFileURL, options: [.atomic])
    }

    func preparedFileURL(for fileName: String) throws -> URL {
        try fileManager.createDirectory(at: voiceMemoDirectoryURL, withIntermediateDirectories: true)
        return fileURL(for: fileName)
    }

    func fileURL(for fileName: String) -> URL {
        voiceMemoDirectoryURL.appendingPathComponent(fileName)
    }

    func deleteAudioFile(for voiceMemo: VoiceMemo) throws {
        let fileURL = fileURL(for: voiceMemo.fileName)

        if fileManager.fileExists(atPath: fileURL.path) {
            try fileManager.removeItem(at: fileURL)
        }
    }

    func deleteAudioFiles(for voiceMemos: [VoiceMemo]) throws {
        for voiceMemo in voiceMemos {
            try deleteAudioFile(for: voiceMemo)
        }
    }
}

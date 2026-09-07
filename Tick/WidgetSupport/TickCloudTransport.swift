import CloudKit
import Foundation

nonisolated struct TickCloudRemote: Sendable {
    var payload: TickCloudPayload
    var version: Data?
}

nonisolated enum TickCloudError: LocalizedError {
    case conflict
    case accountChanged
    case invalidRecord
    case busy

    var errorDescription: String? {
        switch self {
        case .conflict, .busy: "Changes are saved on this device and will retry syncing."
        case .accountChanged: "Your iCloud account changed. Existing time is preserved on this device; syncing is paused to keep accounts separate."
        case .invalidRecord: "Tick could not read its iCloud record. Your local time is preserved."
        }
    }
}

nonisolated protocol TickCloudTransport: Sendable {
    func accountID() async throws -> String
    func subscribe() async throws
    func fetch() async throws -> TickCloudRemote?
    func save(_ payload: TickCloudPayload, version: Data?) async throws -> TickCloudRemote
}

actor TickCloudKitTransport: TickCloudTransport {
    private let container = CKContainer(identifier: TickSharedStorage.iCloudContainerIdentifier)
    private let recordID = CKRecord.ID(recordName: "snapshot-v1")
    private var database: CKDatabase { container.privateCloudDatabase }
    nonisolated static let subscriptionID = "tick-snapshot-v1"

    func accountID() async throws -> String {
        try await container.userRecordID().recordName
    }

    func subscribe() async throws {
        do {
            _ = try await database.subscription(for: Self.subscriptionID)
            return
        } catch let error as CKError where error.code == .unknownItem {
            // A new install/account creates the same idempotent subscription.
        }
        let subscription = CKQuerySubscription(
            recordType: "TickSnapshotV1", predicate: NSPredicate(value: true),
            subscriptionID: Self.subscriptionID,
            options: [.firesOnRecordCreation, .firesOnRecordUpdate]
        )
        let info = CKSubscription.NotificationInfo()
        info.shouldSendContentAvailable = true
        subscription.notificationInfo = info
        do {
            _ = try await database.save(subscription)
        } catch {
            // Another device can create the shared subscription after our fetch.
            // Confirm its existence instead of treating that race as a failed timer save.
            guard (try? await database.subscription(for: Self.subscriptionID)) != nil else { throw error }
        }
    }

    func fetch() async throws -> TickCloudRemote? {
        do {
            let record = try await database.record(for: recordID)
            guard let asset = record["payload"] as? CKAsset, let url = asset.fileURL else {
                throw TickCloudError.invalidRecord
            }
            return TickCloudRemote(payload: try TickCloudCodec.decode(TickCloudPayload.self, from: Data(contentsOf: url)),
                                   version: archive(record))
        } catch let error as CKError where error.code == .unknownItem {
            return nil
        }
    }

    func save(_ payload: TickCloudPayload, version: Data?) async throws -> TickCloudRemote {
        let record: CKRecord
        if let version {
            let coder = try NSKeyedUnarchiver(forReadingFrom: version)
            coder.requiresSecureCoding = true
            defer { coder.finishDecoding() }
            guard let decoded = CKRecord(coder: coder) else { throw TickCloudError.invalidRecord }
            record = decoded
        } else {
            record = CKRecord(recordType: "TickSnapshotV1", recordID: recordID)
        }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try TickCloudCodec.encode(payload).write(to: url, options: .atomic)
        defer { try? FileManager.default.removeItem(at: url) }
        record["payload"] = CKAsset(fileURL: url)
        do {
            let results = try await database.modifyRecords(saving: [record], deleting: [],
                                                          savePolicy: .ifServerRecordUnchanged, atomically: true)
            guard let result = results.saveResults[recordID] else { throw TickCloudError.invalidRecord }
            let saved = try result.get()
            return TickCloudRemote(payload: payload, version: archive(saved))
        } catch {
            if TickCloudFailure.isConflict(error) { throw TickCloudError.conflict }
            throw error
        }
    }

    private func archive(_ record: CKRecord) -> Data {
        let coder = NSKeyedArchiver(requiringSecureCoding: true)
        record.encodeSystemFields(with: coder)
        coder.finishEncoding()
        return coder.encodedData
    }
}

nonisolated enum TickCloudFailure {
    static func isConflict(_ error: Error) -> Bool {
        guard let cloudError = error as? CKError else { return false }
        if cloudError.code == .serverRecordChanged { return true }
        guard cloudError.code == .partialFailure else { return false }
        return cloudError.partialErrorsByItemID?.values.contains(where: isConflict) == true
    }

    static func diagnostic(_ error: Error) -> String {
        let nsError = error as NSError
        let children = (error as? CKError)?.partialErrorsByItemID?.values.map {
            let child = $0 as NSError
            return "\(child.domain):\(child.code)"
        }.sorted().joined(separator: ",") ?? ""
        return "\(nsError.domain):\(nsError.code) [\(children)]"
    }
}

nonisolated enum TickCloudCodec {
    static func encode<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(value)
    }

    static func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(type, from: data)
    }
}

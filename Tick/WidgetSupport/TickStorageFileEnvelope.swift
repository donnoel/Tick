import Foundation

nonisolated struct TickStorageFileEnvelope<Snapshot: Codable>: Codable {
    var updatedAt: Date
    var snapshot: Snapshot
    var cloudSync: TickCloudCheckpoint? = nil
}

extension TickStorageFileEnvelope {
    /// A damaged envelope must never be interpreted as an empty legacy snapshot.
    nonisolated static func hasEnvelopeShape(_ data: Data) throws -> Bool {
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw CocoaError(.coderReadCorrupt)
        }
        if object["snapshot"] != nil || object["updatedAt"] != nil || object["cloudSync"] != nil {
            return true
        }
        guard object["projects"] != nil, object["sessions"] != nil else {
            throw CocoaError(.coderReadCorrupt)
        }
        return false
    }
}

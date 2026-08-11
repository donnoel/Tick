import Foundation

nonisolated struct TickStorageFileEnvelope<Snapshot: Codable>: Codable {
    var updatedAt: Date
    var snapshot: Snapshot
}

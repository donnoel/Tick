import Foundation

nonisolated struct TickStorageSnapshot: Codable, Equatable {
    var projects: [TickProject]
    var sessions: [TimeSession]

    static let empty = TickStorageSnapshot(projects: [], sessions: [])
}

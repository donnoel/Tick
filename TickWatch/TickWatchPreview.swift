#if targetEnvironment(simulator)
import CloudKit
import Foundation
import TickCore

/// Isolated simulator fixtures never read or write a live CloudKit account.
@MainActor
enum TickWatchPreview {
    static func store() -> TickCloudClientStore {
        let path = FileManager.default.temporaryDirectory.appendingPathComponent("tick-watch-preview.json")
        return TickCloudClientStore(transport: PreviewTransport(), fileURL: path)
    }

    static func twoActiveStore() -> TickCloudClientStore {
        let path = FileManager.default.temporaryDirectory
            .appendingPathComponent("tick-watch-two-active-\(UUID().uuidString).json")
        return TickCloudClientStore(
            transport: PreviewTransport(initialSnapshot: twoActiveSnapshot()), fileURL: path
        )
    }

    private static func twoActiveSnapshot() -> TickWidgetStorageSnapshot {
        let beamID = UUID(uuidString: "10000000-0000-0000-0000-000000000001")!
        let mosaID = UUID(uuidString: "10000000-0000-0000-0000-000000000002")!
        let tickID = UUID(uuidString: "10000000-0000-0000-0000-000000000003")!
        let startedAt = Date.now.addingTimeInterval(-120)
        return TickWidgetStorageSnapshot(
            projects: [
                TickWidgetStoredProject(id: beamID, name: "Beam", createdAt: .distantPast, isArchived: false, sortOrder: 0),
                TickWidgetStoredProject(id: mosaID, name: "Mosa", createdAt: .distantPast, isArchived: false, sortOrder: 1),
                TickWidgetStoredProject(id: tickID, name: "Tick", createdAt: .distantPast, isArchived: false, sortOrder: 2)
            ],
            sessions: [mosaID, tickID].enumerated().map { index, projectID in
                TickWidgetStoredSession(
                    id: UUID(uuidString: "20000000-0000-0000-0000-00000000000\(index + 1)")!,
                    projectID: projectID, title: "", notes: "", startedAt: startedAt.addingTimeInterval(Double(index) * 30),
                    endedAt: nil, manualDuration: nil, entrySource: "timer", autoTickRuleID: nil,
                    createdAt: startedAt.addingTimeInterval(Double(index) * 30)
                )
            }
        )
    }

    static func unavailableStore() -> TickCloudClientStore {
        TickCloudClientStore(transport: UnavailableTransport(), fileURL:
            FileManager.default.temporaryDirectory.appendingPathComponent("tick-watch-simulator.json"))
    }

    private actor UnavailableTransport: TickCloudTransport {
        enum Failure: LocalizedError {
            case unavailable
            var errorDescription: String? { "iCloud is unavailable in this simulator." }
        }
        func accountID() throws -> String { throw Failure.unavailable }
        func subscribe() throws { throw Failure.unavailable }
        func fetch() throws -> TickCloudRemote? { throw Failure.unavailable }
        func save(_ payload: TickCloudPayload, version: Data?) throws -> TickCloudRemote { throw Failure.unavailable }
    }

    private actor PreviewTransport: TickCloudTransport {
        private var payload: TickCloudPayload
        private let fileURL: URL

        init(initialSnapshot: TickWidgetStorageSnapshot? = nil) {
            fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(
                initialSnapshot == nil ? "tick-watch-preview-cloud.json" : "tick-watch-two-active-cloud-\(UUID().uuidString).json"
            )
            if let initialSnapshot {
                payload = TickCloudPayload(snapshot: initialSnapshot)
                return
            }
            if let data = try? Data(contentsOf: fileURL), let saved = try? TickCloudCodec.decode(TickCloudPayload.self, from: data) {
                payload = saved
                return
            }
            payload = TickCloudPayload(snapshot: TickWidgetStorageSnapshot(projects: [
            TickWidgetStoredProject(id: UUID(uuidString: "10000000-0000-0000-0000-000000000001")!, name: "Beam", createdAt: .distantPast, isArchived: false, sortOrder: 0),
            TickWidgetStoredProject(id: UUID(uuidString: "10000000-0000-0000-0000-000000000002")!, name: "Mosa", createdAt: .distantPast, isArchived: false, sortOrder: 1),
            TickWidgetStoredProject(id: UUID(uuidString: "10000000-0000-0000-0000-000000000003")!, name: "Tick", createdAt: .distantPast, isArchived: false, sortOrder: 2)
        ], sessions: []))
        }
        func accountID() -> String { "watch-preview" }
        func subscribe() {}
        func fetch() throws -> TickCloudRemote? {
            if ProcessInfo.processInfo.arguments.contains("-watchPreviewOffline") { throw CKError(.networkUnavailable) }
            return TickCloudRemote(payload: payload, version: nil)
        }
        func save(_ payload: TickCloudPayload, version: Data?) throws -> TickCloudRemote {
            try TickCloudCodec.encode(payload).write(to: fileURL, options: .atomic)
            self.payload = payload
            return TickCloudRemote(payload: payload, version: nil)
        }
    }
}
#endif

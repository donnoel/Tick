import Foundation
import XCTest
@testable import Tick

final class TickCloudSyncStoreTests: XCTestCase {
    func testAccountChangeLeavesLocalSnapshotAndCloudUntouched() async throws {
        let urls = temporaryURLs()
        defer { try? FileManager.default.removeItem(at: urls.folder) }
        let project = TickProject(name: "Studio", createdAt: Date(timeIntervalSince1970: 100))
        let dataStore = TickDataStore(fileURL: urls.data)
        try await dataStore.save(TickStorageSnapshot(projects: [project], sessions: []))
        let cloud = AppSyncTestCloud()
        let sync = TickCloudSyncStore(
            transport: cloud, fileURL: urls.data, widgetURL: urls.widget, importsLegacy: false
        )
        _ = try await sync.synchronize()
        let acknowledged = try TickCloudCodec.decode(
            TickStorageFileEnvelope<TickWidgetStorageSnapshot>.self,
            from: Data(contentsOf: urls.data)
        )
        XCTAssertEqual(acknowledged.cloudSync?.accountID, "account-A")
        XCTAssertEqual(acknowledged.cloudSync?.acknowledged?.snapshot.projects.map(\.id), [project.id])
        XCTAssertNotNil(acknowledged.cloudSync?.confirmedAt)
        let original = try Data(contentsOf: urls.data)
        let saveCount = await cloud.saveCount
        await cloud.changeAccount()

        do {
            _ = try await sync.synchronize()
            XCTFail("A changed account must not receive cached time")
        } catch {
            XCTAssertTrue(error.localizedDescription.contains("account changed"))
        }
        XCTAssertEqual(try Data(contentsOf: urls.data), original)
        let finalSaveCount = await cloud.saveCount
        XCTAssertEqual(finalSaveCount, saveCount)
    }

    func testEditMadeDuringCloudUploadRemainsInLocalAndRemoteSnapshots() async throws {
        let urls = temporaryURLs()
        defer { try? FileManager.default.removeItem(at: urls.folder) }
        let project = TickProject(name: "Studio", createdAt: Date(timeIntervalSince1970: 100))
        let dataStore = TickDataStore(fileURL: urls.data)
        try await dataStore.save(TickStorageSnapshot(projects: [project], sessions: []))
        let cloud = AppSyncTestCloud()
        let session = TickWidgetStoredSession(
            id: UUID(), projectID: project.id, title: "Added during upload", notes: "",
            startedAt: Date(timeIntervalSince1970: 200), endedAt: nil,
            manualDuration: 60, entrySource: "manual", autoTickRuleID: nil,
            createdAt: Date(timeIntervalSince1970: 200)
        )
        await cloud.addLocalSessionOnNextSave(session, fileURL: urls.data)
        let sync = TickCloudSyncStore(
            transport: cloud, fileURL: urls.data, widgetURL: urls.widget, importsLegacy: false
        )

        _ = try await sync.synchronize()
        let local = try await dataStore.load()
        let remote = await cloud.payload
        let saveCount = await cloud.saveCount
        XCTAssertEqual(local.sessions.map(\.id), [session.id])
        XCTAssertEqual(remote?.snapshot.sessions.map(\.id), [session.id])
        XCTAssertGreaterThanOrEqual(saveCount, 2)
    }

    func testConflictRetryKeepsBothClientsManualSessions() async throws {
        let urls = temporaryURLs()
        defer { try? FileManager.default.removeItem(at: urls.folder) }
        let project = TickProject(name: "Studio", createdAt: Date(timeIntervalSince1970: 100))
        let dataStore = TickDataStore(fileURL: urls.data)
        try await dataStore.save(TickStorageSnapshot(projects: [project], sessions: []))
        let cloud = AppSyncTestCloud()
        let sync = TickCloudSyncStore(
            transport: cloud, fileURL: urls.data, widgetURL: urls.widget, importsLegacy: false
        )
        _ = try await sync.synchronize()
        let localSession = TimeSession(
            projectID: project.id, title: "Phone", notes: "",
            startedAt: Date(timeIntervalSince1970: 200), endedAt: nil,
            manualDuration: 60, entrySource: .manual,
            createdAt: Date(timeIntervalSince1970: 200)
        )
        try await dataStore.save(TickStorageSnapshot(projects: [project], sessions: [localSession]))
        let remoteSession = TickWidgetStoredSession(
            id: UUID(), projectID: project.id, title: "iPad", notes: "",
            startedAt: Date(timeIntervalSince1970: 300), endedAt: nil,
            manualDuration: 120, entrySource: "manual", autoTickRuleID: nil,
            createdAt: Date(timeIntervalSince1970: 300)
        )
        let initialRemote = await cloud.payload
        var remoteSnapshot = try XCTUnwrap(initialRemote?.snapshot)
        remoteSnapshot.sessions = [remoteSession]
        await cloud.conflictOnNextSave(with: TickCloudPayload(snapshot: remoteSnapshot))

        _ = try await sync.synchronize()
        let local = try await dataStore.load()
        let remote = await cloud.payload
        XCTAssertEqual(Set(local.sessions.map(\.id)), Set([localSession.id, remoteSession.id]))
        XCTAssertEqual(Set(remote?.snapshot.sessions.map(\.id) ?? []), Set([localSession.id, remoteSession.id]))
    }

    func testMalformedEnvelopeCannotBeUploadedAsEmptyHistory() async throws {
        let urls = temporaryURLs()
        defer { try? FileManager.default.removeItem(at: urls.folder) }
        try FileManager.default.createDirectory(at: urls.folder, withIntermediateDirectories: true)
        let damaged = Data(#"{"updatedAt":"bad-date","snapshot":{"projects":[],"sessions":[]}}"#.utf8)
        try damaged.write(to: urls.data, options: .atomic)
        let cloud = AppSyncTestCloud()
        let sync = TickCloudSyncStore(
            transport: cloud, fileURL: urls.data, widgetURL: urls.widget, importsLegacy: false
        )
        do {
            _ = try await sync.synchronize()
            XCTFail("A malformed envelope must block cloud publication")
        } catch {}
        let saveCount = await cloud.saveCount
        XCTAssertEqual(saveCount, 0)
        XCTAssertEqual(try Data(contentsOf: urls.data), damaged)
    }

    private func temporaryURLs() -> (folder: URL, data: URL, widget: URL) {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        return (folder, folder.appendingPathComponent("tick-data.json"),
                folder.appendingPathComponent("tick-widget-snapshot.json"))
    }
}

private actor AppSyncTestCloud: TickCloudTransport {
    private var account = "account-A"
    private(set) var payload: TickCloudPayload?
    private(set) var saveCount = 0
    private var localEdit: (session: TickWidgetStoredSession, fileURL: URL)?
    private var conflictingPayload: TickCloudPayload?

    func accountID() throws -> String { account }
    func subscribe() {}
    func fetch() -> TickCloudRemote? {
        payload.map { TickCloudRemote(payload: $0, version: nil) }
    }
    func changeAccount() { account = "account-B" }
    func addLocalSessionOnNextSave(_ session: TickWidgetStoredSession, fileURL: URL) {
        localEdit = (session, fileURL)
    }
    func conflictOnNextSave(with payload: TickCloudPayload) { conflictingPayload = payload }

    func save(_ payload: TickCloudPayload, version: Data?) throws -> TickCloudRemote {
        saveCount += 1
        if let conflictingPayload {
            self.conflictingPayload = nil
            self.payload = conflictingPayload
            throw TickCloudError.conflict
        }
        if let localEdit {
            self.localEdit = nil
            try TickSharedFileCoordinator.coordinateWriting(at: localEdit.fileURL) { url in
                var envelope = try TickCloudCodec.decode(
                    TickStorageFileEnvelope<TickWidgetStorageSnapshot>.self,
                    from: Data(contentsOf: url)
                )
                envelope.snapshot.sessions.append(localEdit.session)
                try TickCloudCodec.encode(envelope).write(to: url, options: .atomic)
            }
        }
        self.payload = payload
        return TickCloudRemote(payload: payload, version: nil)
    }
}

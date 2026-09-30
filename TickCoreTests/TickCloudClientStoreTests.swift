import CloudKit
import Foundation
import Testing
@testable import TickCore

struct TickCloudClientStoreTests {
    private let date = Date(timeIntervalSince1970: 1_700_000_000)

    private func fixture() -> TickWidgetStorageSnapshot {
        TickWidgetStorageSnapshot(projects: [TickWidgetStoredProject(
            id: UUID(), name: "Beam", createdAt: date, isArchived: false
        )], sessions: [])
    }

    private func path() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("state.json")
    }

    @Test func firstConnectionNeverCreatesAnEmptyCloudRecord() async throws {
        let cloud = ClientTestCloud(payload: nil)
        let url = path()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let store = TickCloudClientStore(transport: cloud, fileURL: url)
        let state = try await store.refresh()
        #expect(!state.canRecord)
        await #expect(throws: TickCloudClientStore.Failure.self) {
            try await store.perform(.start(projectID: UUID(), sessionID: UUID(), at: date))
        }
        #expect(await cloud.saveCount == 0)
        #expect(!FileManager.default.fileExists(atPath: url.path))
    }

    @Test func offlinePauseResumeStopSurviveRelaunchAndReachAnotherClient() async throws {
        let snapshot = fixture()
        let cloud = ClientTestCloud(payload: TickCloudPayload(snapshot: snapshot))
        let watchURL = path(), phoneURL = path()
        defer {
            try? FileManager.default.removeItem(at: watchURL.deletingLastPathComponent())
            try? FileManager.default.removeItem(at: phoneURL.deletingLastPathComponent())
        }
        let watch = TickCloudClientStore(transport: cloud, fileURL: watchURL)
        let phone = TickCloudClientStore(transport: cloud, fileURL: phoneURL)
        _ = try await watch.refresh()
        _ = try await phone.refresh()
        await cloud.setOffline(true)
        let id = UUID()
        _ = try await watch.perform(.start(projectID: snapshot.projects[0].id, sessionID: id, at: date))
        _ = try await watch.perform(.pause(sessionID: id, at: date.addingTimeInterval(60)))
        let relaunched = TickCloudClientStore(transport: cloud, fileURL: watchURL)
        #expect(try await relaunched.load().snapshot.sessions[0].duration(at: date.addingTimeInterval(120)) == 60)
        _ = try await relaunched.perform(.resume(sessionID: id, at: date.addingTimeInterval(120)))
        let stopped = try await relaunched.perform(.stop(sessionID: id, at: date.addingTimeInterval(180)))
        #expect(stopped.hasPendingChanges)
        #expect(stopped.snapshot.sessions[0].duration(at: date.addingTimeInterval(240)) == 120)
        await cloud.setOffline(false)
        let synced = try await relaunched.refresh()
        #expect(!synced.hasPendingChanges)
        let received = try await phone.refresh()
        #expect(received.snapshot == synced.snapshot)
        #expect(received.snapshot.sessions[0].endedAt == date.addingTimeInterval(180))
    }

    @Test func refreshBeforeStopNeverStopsAReplacementTick() async throws {
        var initial = fixture()
        let old = UUID(), replacement = UUID()
        try TickTimerMutation.start(in: &initial, projectID: initial.projects[0].id, sessionID: old, at: date)
        let cloud = ClientTestCloud(payload: TickCloudPayload(snapshot: initial))
        let url = path()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let watch = TickCloudClientStore(transport: cloud, fileURL: url)
        _ = try await watch.refresh()
        var phone = initial
        try TickTimerMutation.stop(in: &phone, sessionID: old, at: date.addingTimeInterval(10))
        try TickTimerMutation.start(in: &phone, projectID: initial.projects[0].id, sessionID: replacement, at: date.addingTimeInterval(20))
        await cloud.replace(TickCloudPayload(snapshot: phone))
        let state = try await watch.perform(.stop(sessionID: old, at: date.addingTimeInterval(30)))
        #expect(state.snapshot.sessions.first(where: \.isActive)?.id == replacement)
        #expect(!state.hasPendingChanges)
    }

    @Test func changedAccountPreservesCacheAndBlocksMutation() async throws {
        let cloud = ClientTestCloud(payload: TickCloudPayload(snapshot: fixture()))
        let url = path()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let watch = TickCloudClientStore(transport: cloud, fileURL: url)
        let state = try await watch.refresh()
        let originalFile = try Data(contentsOf: url)
        await cloud.changeAccount()
        await #expect(throws: TickCloudError.self) {
            try await watch.perform(.start(projectID: state.snapshot.projects[0].id, sessionID: UUID(), at: date))
        }
        #expect(try Data(contentsOf: url) == originalFile)
        #expect(await cloud.saveCount == 0)
    }

    @Test func corruptCacheIsPreservedWithoutCloudWrites() async throws {
        let cloud = ClientTestCloud(payload: TickCloudPayload(snapshot: fixture()))
        let url = path()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let original = Data("invalid cache".utf8)
        try original.write(to: url)
        let watch = TickCloudClientStore(transport: cloud, fileURL: url)
        await #expect(throws: TickCloudClientStore.Failure.self) { try await watch.refresh() }
        #expect(try Data(contentsOf: url) == original)
        #expect(await cloud.saveCount == 0)
    }

    @Test func disappearedCloudRecordCannotBeRecreatedFromStaleCache() async throws {
        let cloud = ClientTestCloud(payload: TickCloudPayload(snapshot: fixture()))
        let url = path()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let watch = TickCloudClientStore(transport: cloud, fileURL: url)
        let initial = try await watch.refresh()
        await cloud.replace(nil)
        await #expect(throws: TickCloudError.self) {
            try await watch.perform(.start(projectID: initial.snapshot.projects[0].id, sessionID: UUID(), at: date))
        }
        #expect(try await watch.load().snapshot == initial.snapshot)
        #expect(await cloud.saveCount == 0)
    }

    @Test func conflictRetryUsesSharedMergeAndPreservesRulesAndTombstones() async throws {
        var snapshot = fixture()
        let space = snapshot.projects[0].id
        let id = UUID()
        try TickTimerMutation.start(in: &snapshot, projectID: space, sessionID: id, at: date)
        snapshot.autoTickRules = [TickWidgetStoredAutoTickRule(id: UUID(), projectID: space, name: "Office",
            latitude: 40, longitude: -70, radiusMeters: 100, startsOnArrival: true,
            stopsOnDeparture: true, isEnabled: true, createdAt: date)]
        let tombstone = UUID()
        let cloud = ClientTestCloud(payload: TickCloudPayload(snapshot: snapshot, deletedSessions: [tombstone]))
        let url = path()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let watch = TickCloudClientStore(transport: cloud, fileURL: url)
        _ = try await watch.refresh()
        _ = try await watch.perform(.pause(sessionID: id, at: date.addingTimeInterval(60)))
        var remote = snapshot
        remote.sessions[0].notes = "Written on the iPad"
        await cloud.conflictOnNextSave(with: TickCloudPayload(snapshot: remote, deletedSessions: [tombstone]))
        let synced = try await watch.refresh()
        #expect(!synced.hasPendingChanges)
        #expect(synced.snapshot.autoTickRules == snapshot.autoTickRules)
        #expect(synced.checkpoint?.acknowledged?.deletedSessions.contains(tombstone) == true)
        // Existing record-level conflict rules apply; a newer remote stop remains terminal.
        var stopped = synced.snapshot
        try TickTimerMutation.stop(in: &stopped, sessionID: id, at: date.addingTimeInterval(100))
        stopped.sessions[0].notes = "Written on the iPad"
        await cloud.replace(TickCloudPayload(snapshot: stopped, deletedSessions: [tombstone]))
        let received = try await watch.refresh()
        #expect(received.snapshot.sessions[0].notes == "Written on the iPad")
        #expect(!received.snapshot.sessions[0].isActive)
    }
}

private actor ClientTestCloud: TickCloudTransport {
    private var payload: TickCloudPayload?
    private var offline = false
    private var account = "account-one"
    private var conflictingPayload: TickCloudPayload?
    private(set) var saveCount = 0

    init(payload: TickCloudPayload?) { self.payload = payload }
    func setOffline(_ value: Bool) { offline = value }
    func replace(_ payload: TickCloudPayload?) { self.payload = payload }
    func changeAccount() { account = "account-two" }
    func conflictOnNextSave(with payload: TickCloudPayload) { conflictingPayload = payload }
    func accountID() throws -> String {
        if offline { throw CKError(.networkUnavailable) }
        return account
    }
    func subscribe() {}
    func fetch() -> TickCloudRemote? { payload.map { TickCloudRemote(payload: $0, version: nil) } }
    func save(_ payload: TickCloudPayload, version: Data?) throws -> TickCloudRemote {
        saveCount += 1
        if let conflict = conflictingPayload {
            self.payload = conflict
            conflictingPayload = nil
            throw TickCloudError.conflict
        }
        self.payload = payload
        return TickCloudRemote(payload: payload, version: nil)
    }
}

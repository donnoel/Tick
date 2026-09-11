import Foundation
import Testing
@testable import TickCore

struct TickCoreTests {
    private let date = Date(timeIntervalSince1970: 1_700_000_000)

    private func snapshot() -> TickWidgetStorageSnapshot {
        TickWidgetStorageSnapshot(projects: [TickWidgetStoredProject(
            id: UUID(), name: "Beam", createdAt: date, isArchived: false
        )], sessions: [])
    }

    @Test func timerPreservesPausedDurationAndStopIsIdempotent() throws {
        var state = snapshot()
        let id = UUID()
        try TickTimerMutation.start(in: &state, projectID: state.projects[0].id, sessionID: id, at: date)
        state.sessions[0].accumulatedPausedDuration = 20
        state.sessions[0].pausedAt = date.addingTimeInterval(100)
        try TickTimerMutation.stop(in: &state, sessionID: id, at: date.addingTimeInterval(200))
        #expect(state.sessions[0].duration(at: date.addingTimeInterval(300)) == 80)
        #expect(state.sessions[0].pausedAt == nil)
        let stopped = state
        try TickTimerMutation.stop(in: &state, sessionID: id, at: date.addingTimeInterval(400))
        #expect(state == stopped)
    }

    @Test func pauseAndResumeExcludePausedTimeAndAreIdempotent() throws {
        var state = snapshot()
        let id = UUID()
        try TickTimerMutation.start(in: &state, projectID: state.projects[0].id, sessionID: id, at: date)

        try TickTimerMutation.pause(in: &state, sessionID: id, at: date.addingTimeInterval(100))
        try TickTimerMutation.pause(in: &state, sessionID: id, at: date.addingTimeInterval(150))
        #expect(state.sessions[0].pausedAt == date.addingTimeInterval(100))
        #expect(state.sessions[0].duration(at: date.addingTimeInterval(200)) == 100)

        try TickTimerMutation.resume(in: &state, sessionID: id, at: date.addingTimeInterval(200))
        let resumed = state
        try TickTimerMutation.resume(in: &state, sessionID: id, at: date.addingTimeInterval(250))
        #expect(state == resumed)
        #expect(state.sessions[0].accumulatedPausedDuration == 100)
        #expect(state.sessions[0].duration(at: date.addingTimeInterval(300)) == 200)
    }

    @Test func startRejectsArchivedSpacesAndDuplicateTimers() throws {
        var state = snapshot()
        state.projects[0].isArchived = true
        #expect(throws: TickTimerMutation.Failure.unavailableSpace) {
            try TickTimerMutation.start(in: &state, projectID: state.projects[0].id, at: date)
        }
        state.projects[0].isArchived = false
        try TickTimerMutation.start(in: &state, projectID: state.projects[0].id, at: date)
        #expect(throws: TickTimerMutation.Failure.alreadyActive) {
            try TickTimerMutation.start(in: &state, projectID: state.projects[0].id, at: date)
        }
        #expect(state.sessions.count == 1)
    }

    @Test func staleStopCannotStopAnotherSession() throws {
        var state = snapshot()
        let first = UUID()
        try TickTimerMutation.start(in: &state, projectID: state.projects[0].id, sessionID: first, at: date)
        try TickTimerMutation.stop(in: &state, sessionID: first, at: date.addingTimeInterval(10))
        let next = UUID()
        try TickTimerMutation.start(in: &state, projectID: state.projects[0].id,
                                    sessionID: next, at: date.addingTimeInterval(20))
        try TickTimerMutation.stop(in: &state, sessionID: first, at: date.addingTimeInterval(30))
        #expect(state.sessions.first(where: \.isActive)?.id == next)
    }

    @Test func concurrentStartsConvergeAndKeepBothRecords() throws {
        let base = snapshot()
        var phone = base
        var mac = base
        try TickTimerMutation.start(in: &phone, projectID: base.projects[0].id, at: date)
        try TickTimerMutation.start(in: &mac, projectID: base.projects[0].id, at: date.addingTimeInterval(10))
        let merged = TickCloudMerge.resolve(base: base, local: mac, remote: TickCloudPayload(snapshot: phone))
        #expect(merged.snapshot.sessions.count == 2)
        #expect(merged.snapshot.sessions.filter(\.isActive).count == 1)
        #expect(merged.snapshot.sessions.first(where: \.isActive)?.id == mac.sessions[0].id)
    }

    @Test func stopWinsOverStaleMetadataEdit() throws {
        var base = snapshot()
        try TickTimerMutation.start(in: &base, projectID: base.projects[0].id, at: date)
        var phone = base
        var mac = base
        try TickTimerMutation.stop(in: &phone, sessionID: base.sessions[0].id, at: date.addingTimeInterval(50))
        mac.sessions[0].notes = "Edited offline"
        let merged = TickCloudMerge.resolve(base: base, local: mac, remote: TickCloudPayload(snapshot: phone))
        #expect(merged.snapshot.sessions[0].endedAt == date.addingTimeInterval(50))
        #expect(merged.snapshot.sessions[0].notes == "Edited offline")
        #expect(!merged.snapshot.sessions[0].isActive)
    }

    @Test func deletionDoesNotResurrectOnOfflineClient() throws {
        let base = snapshot()
        var offline = base
        try TickTimerMutation.start(in: &offline, projectID: base.projects[0].id, at: date)
        let remote = TickCloudPayload(snapshot: .empty, deletedProjects: [base.projects[0].id])
        let merged = TickCloudMerge.resolve(base: base, local: offline, remote: remote)
        #expect(merged.snapshot.projects.isEmpty)
        #expect(merged.snapshot.sessions.isEmpty)
        #expect(merged.deletedProjects == remote.deletedProjects)
    }

    @Test func wireFormatPreservesFieldsOutsideMacControls() throws {
        var state = snapshot()
        state.autoTickRules = [TickWidgetStoredAutoTickRule(
            id: UUID(), projectID: state.projects[0].id, name: "Office", latitude: 40,
            longitude: -70, radiusMeters: 100, startsOnArrival: true, stopsOnDeparture: true,
            isEnabled: true, createdAt: date
        )]
        try TickTimerMutation.start(in: &state, projectID: state.projects[0].id, at: date)
        state.sessions[0].title = "Research"
        state.sessions[0].notes = "Keep these notes"
        state.sessions[0].pausedAt = date.addingTimeInterval(40)
        state.sessions[0].accumulatedPausedDuration = 10
        let payload = TickCloudPayload(snapshot: state, deletedSessions: [UUID()])
        #expect(try TickCloudCodec.decode(TickCloudPayload.self, from: TickCloudCodec.encode(payload)) == payload)
    }
}

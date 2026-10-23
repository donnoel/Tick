import XCTest
@testable import Tick

final class SessionTimingTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 1_700_000_000)

    private func manual() -> TimeSession {
        TimeSession(projectID: UUID(), title: "Work", notes: "Notes", startedAt: start,
                    endedAt: nil, manualDuration: 1_800.25, entrySource: .manual, createdAt: start)
    }

    func testManualDateStartAndDurationCanBeCorrectedWithoutChangingIdentity() throws {
        let session = manual()
        var draft = SessionTimingDraft(session: session)
        XCTAssertFalse(draft.hasChanges)
        draft.startedAt = start.addingTimeInterval(-86_400)
        draft.duration = 5_401
        let updated = try draft.applying(to: session)
        XCTAssertEqual(updated.id, session.id)
        XCTAssertEqual(updated.createdAt, session.createdAt)
        XCTAssertEqual(updated.title, session.title)
        XCTAssertEqual(updated.notes, session.notes)
        XCTAssertEqual(updated.referenceDate, draft.startedAt)
        XCTAssertEqual(updated.manualDuration, 5_401)
        XCTAssertNil(updated.endedAt)
        XCTAssertFalse(updated.isActive)
    }

    func testEndAndDurationStayConsistentAndPreserveRecordedPauses() throws {
        let session = TimeSession(projectID: UUID(), title: "Work", notes: "", startedAt: start,
                                  endedAt: start.addingTimeInterval(7_200), manualDuration: nil,
                                  accumulatedPausedDuration: 900, entrySource: .timer)
        var draft = SessionTimingDraft(session: session)
        XCTAssertEqual(draft.duration, 6_300)
        draft.duration = 3_600
        XCTAssertEqual(draft.endedAt, start.addingTimeInterval(4_500))
        draft.endedAt = start.addingTimeInterval(8_100)
        XCTAssertEqual(draft.duration, 7_200)
        draft.startedAt = start.addingTimeInterval(86_400)
        let updated = try draft.applying(to: session)
        XCTAssertEqual(updated.endedAt, draft.startedAt.addingTimeInterval(8_100))
        XCTAssertEqual(updated.duration(), 7_200)
        XCTAssertEqual(updated.accumulatedPausedDuration, 900)
        draft.endedAt = draft.startedAt.addingTimeInterval(300)
        XCTAssertNotNil(draft.validationMessage)
        XCTAssertThrowsError(try draft.applying(to: session))
    }

    func testEverySourceConversionKeepsACompletedTickAndClearsUnrelatedAutoLinkage() throws {
        for originalSource in SessionEntrySource.allCases {
            let session = TimeSession(projectID: UUID(), title: "Work", notes: "", startedAt: start,
                                      endedAt: originalSource == .manual ? nil : start.addingTimeInterval(3_600),
                                      manualDuration: originalSource == .manual ? 3_600 : nil,
                                      entrySource: originalSource, autoTickRuleID: originalSource == .autoLocation ? UUID() : nil)
            for source in SessionEntrySource.allCases {
                var draft = SessionTimingDraft(session: session)
                draft.source = source
                let updated = try draft.applying(to: session)
                XCTAssertEqual(updated.entrySource, source)
                XCTAssertEqual(updated.duration(), 3_600)
                XCTAssertFalse(updated.isActive)
                XCTAssertNil(updated.pausedAt)
                if source == .manual {
                    XCTAssertEqual(updated.manualDuration, 3_600)
                    XCTAssertNil(updated.accumulatedPausedDuration)
                } else {
                    XCTAssertNil(updated.manualDuration)
                    XCTAssertNotNil(updated.endedAt)
                }
                if source != .autoLocation { XCTAssertNil(updated.autoTickRuleID) }
            }
        }
    }

    func testInvalidDurationsAndStaleOrActiveTimingAreRejected() throws {
        let session = manual()
        var draft = SessionTimingDraft(session: session)
        for duration in [0, -1, Double.nan, .infinity] {
            draft.duration = duration
            XCTAssertNotNil(draft.validationMessage)
            XCTAssertThrowsError(try draft.applying(to: session))
        }
        draft = SessionTimingDraft(session: session)
        draft.duration = 900
        var changed = session
        changed.manualDuration = 7_200
        XCTAssertThrowsError(try draft.applying(to: changed))
        changed = session
        changed.title = "Updated elsewhere"
        XCTAssertEqual(try draft.applying(to: changed).title, "Updated elsewhere")
        let running = TimeSession(projectID: session.projectID, title: "Live", notes: "", startedAt: start,
                                  endedAt: nil, manualDuration: nil, entrySource: .timer)
        var activeDraft = SessionTimingDraft(session: running, at: start.addingTimeInterval(60))
        activeDraft.duration = 120
        XCTAssertThrowsError(try activeDraft.applying(to: running))
        var paused = running
        paused.pausedAt = start.addingTimeInterval(30)
        XCTAssertThrowsError(try activeDraft.applying(to: paused))
    }

    @MainActor
    func testTimingEditsPersistAndUpdateSummaryWithoutCreatingAnActiveTimer() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let store = TickDataStore(fileURL: folder.appendingPathComponent("tick.json"))
        let model = TickViewModel(store: store)
        await model.addProject(name: "Client", createdAt: start)
        let project = try XCTUnwrap(model.activeProjects.first)
        await model.addManualSession(projectID: project.id, title: "Work", notes: "Notes", date: start, duration: 1_800)
        let session = try XCTUnwrap(model.sessions.first)
        var draft = SessionTimingDraft(session: session)
        draft.startedAt = start.addingTimeInterval(-86_400)
        draft.duration = 5_400
        draft.source = .timer
        let saved = await model.updateSession(id: session.id, title: session.title, notes: session.notes, projectID: project.id, timing: draft)
        XCTAssertTrue(saved)
        let reloaded = TickViewModel(store: TickDataStore(fileURL: folder.appendingPathComponent("tick.json")))
        await reloaded.loadIfNeeded()
        let updated = try XCTUnwrap(reloaded.session(for: session.id))
        XCTAssertEqual(updated.referenceDate, draft.startedAt)
        XCTAssertEqual(updated.entrySource, .timer)
        XCTAssertEqual(updated.duration(), 5_400)
        XCTAssertFalse(updated.isActive)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        XCTAssertEqual(TickSummaryCalculator.summary(for: .day, projects: [project], sessions: reloaded.sessions,
                                                    referenceDate: draft.startedAt, calendar: calendar).totalDuration, 5_400)
        XCTAssertEqual(TickSummaryCalculator.summary(for: .day, projects: [project], sessions: reloaded.sessions,
                                                    referenceDate: start, calendar: calendar).totalDuration, 0)
        let rejected = await reloaded.updateSession(id: session.id, title: "Do not save", notes: "", projectID: project.id, timing: draft)
        XCTAssertFalse(rejected)
        XCTAssertEqual(reloaded.session(for: session.id)?.title, "Work")
    }
}

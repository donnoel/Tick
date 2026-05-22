import XCTest
@testable import Tick

final class TickTests: XCTestCase {
    func testTimerDurationUsesStartedAndEndedDates() {
        let projectID = UUID()
        let startDate = Date(timeIntervalSince1970: 100)
        let endDate = Date(timeIntervalSince1970: 250)
        let session = TimeSession(
            projectID: projectID,
            title: "",
            notes: "",
            startedAt: startDate,
            endedAt: endDate,
            manualDuration: nil,
            entrySource: .timer
        )

        XCTAssertEqual(session.duration(at: Date(timeIntervalSince1970: 400)), 150)
    }

    func testManualDurationWinsOverDates() {
        let projectID = UUID()
        let session = TimeSession(
            projectID: projectID,
            title: "Missed work",
            notes: "",
            startedAt: Date(timeIntervalSince1970: 100),
            endedAt: Date(timeIntervalSince1970: 200),
            manualDuration: 3_600,
            entrySource: .manual
        )

        XCTAssertEqual(session.duration(at: Date(timeIntervalSince1970: 500)), 3_600)
    }

    func testSummaryGroupsSessionsByProjectForSelectedPeriod() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!

        let projectA = TickProject(
            id: UUID(),
            name: "Client A",
            createdAt: Date(timeIntervalSince1970: 0)
        )
        let projectB = TickProject(
            id: UUID(),
            name: "Client B",
            createdAt: Date(timeIntervalSince1970: 0)
        )
        let referenceDate = Date(timeIntervalSince1970: 1_700_000_000)
        let oneHourSession = TimeSession(
            projectID: projectA.id,
            title: "",
            notes: "",
            startedAt: referenceDate,
            endedAt: referenceDate.addingTimeInterval(3_600),
            manualDuration: nil,
            entrySource: .timer
        )
        let manualSession = TimeSession(
            projectID: projectB.id,
            title: "",
            notes: "",
            startedAt: referenceDate.addingTimeInterval(600),
            endedAt: nil,
            manualDuration: 1_800,
            entrySource: .manual
        )
        let oldSession = TimeSession(
            projectID: projectA.id,
            title: "",
            notes: "",
            startedAt: referenceDate.addingTimeInterval(-100_000),
            endedAt: nil,
            manualDuration: 900,
            entrySource: .manual
        )

        let summary = TickSummaryCalculator.summary(
            for: .day,
            projects: [projectA, projectB],
            sessions: [oneHourSession, manualSession, oldSession],
            referenceDate: referenceDate,
            calendar: calendar
        )

        XCTAssertEqual(summary.sessionCount, 2)
        XCTAssertEqual(summary.totalDuration, 5_400)
        XCTAssertEqual(summary.durationByProject.map(\.projectName), ["Client A", "Client B"])
        XCTAssertEqual(summary.durationByProject.map(\.duration), [3_600, 1_800])
    }

    func testDataStoreRoundTripsSnapshot() async throws {
        let fileURL = temporaryStoreURL()
        defer {
            try? FileManager.default.removeItem(at: fileURL.deletingLastPathComponent())
        }

        let createdAt = Date(timeIntervalSince1970: 1_000)
        let project = TickProject(name: "Build Tick", createdAt: createdAt)
        let session = TimeSession(
            projectID: project.id,
            title: "Planning",
            notes: "MVP",
            startedAt: Date(timeIntervalSince1970: 100),
            endedAt: nil,
            manualDuration: 1_200,
            entrySource: .manual,
            createdAt: createdAt
        )
        let snapshot = TickStorageSnapshot(projects: [project], sessions: [session])
        let store = TickDataStore(fileURL: fileURL)

        try await store.save(snapshot)
        let loadedSnapshot = try await store.load()

        XCTAssertEqual(loadedSnapshot, snapshot)
    }

    @MainActor
    func testViewModelPreventsMultipleActiveSessions() async {
        let fileURL = temporaryStoreURL()
        defer {
            try? FileManager.default.removeItem(at: fileURL.deletingLastPathComponent())
        }

        let viewModel = TickViewModel(store: TickDataStore(fileURL: fileURL))
        await viewModel.addProject(name: "Tick", createdAt: Date(timeIntervalSince1970: 0))

        let firstStart = await viewModel.startTick(at: Date(timeIntervalSince1970: 100))
        let secondStart = await viewModel.startTick(at: Date(timeIntervalSince1970: 200))

        XCTAssertTrue(firstStart)
        XCTAssertFalse(secondStart)
        XCTAssertEqual(viewModel.sessions.filter(\.isActive).count, 1)
    }

    @MainActor
    func testViewModelUpdatesSessionDetailsAndPersists() async {
        let fileURL = temporaryStoreURL()
        defer {
            try? FileManager.default.removeItem(at: fileURL.deletingLastPathComponent())
        }

        let store = TickDataStore(fileURL: fileURL)
        let viewModel = TickViewModel(store: store)
        await viewModel.addProject(name: "Original", createdAt: Date(timeIntervalSince1970: 0))
        await viewModel.addProject(name: "New Project", createdAt: Date(timeIntervalSince1970: 10))

        guard let originalProject = viewModel.activeProjects.first,
              let newProject = viewModel.activeProjects.last else {
            XCTFail("Expected test projects to exist.")
            return
        }

        await viewModel.addManualSession(
            projectID: originalProject.id,
            title: "",
            notes: "",
            date: Date(timeIntervalSince1970: 100),
            duration: 1_800
        )

        guard let session = viewModel.sessions.first else {
            XCTFail("Expected a session to update.")
            return
        }

        let didUpdate = await viewModel.updateSession(
            id: session.id,
            title: "  Follow-up planning  ",
            notes: "  Clean up tracked work.  ",
            projectID: newProject.id
        )

        XCTAssertTrue(didUpdate)
        XCTAssertEqual(viewModel.sessions.first?.title, "Follow-up planning")
        XCTAssertEqual(viewModel.sessions.first?.notes, "Clean up tracked work.")
        XCTAssertEqual(viewModel.sessions.first?.projectID, newProject.id)
        XCTAssertEqual(viewModel.sessions.first?.duration(), 1_800)
        XCTAssertEqual(viewModel.sessions.first?.entrySource, .manual)

        let reloadedViewModel = TickViewModel(store: TickDataStore(fileURL: fileURL))
        await reloadedViewModel.loadIfNeeded()

        XCTAssertEqual(reloadedViewModel.sessions.first?.title, "Follow-up planning")
        XCTAssertEqual(reloadedViewModel.sessions.first?.notes, "Clean up tracked work.")
        XCTAssertEqual(reloadedViewModel.sessions.first?.projectID, newProject.id)
    }

    private func temporaryStoreURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent("tick-data.json")
    }
}

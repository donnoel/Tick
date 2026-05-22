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

    func testStorageSnapshotDefaultsMissingAutoTickRules() throws {
        let data = Data(#"{"projects":[],"sessions":[]}"#.utf8)

        let snapshot = try JSONDecoder().decode(TickStorageSnapshot.self, from: data)

        XCTAssertTrue(snapshot.autoTickRules.isEmpty)
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

    @MainActor
    func testViewModelUpdatesAutoTickRuleAndPersists() async {
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

        await viewModel.addAutoTickRule(
            projectID: originalProject.id,
            name: "Office",
            latitude: 37.3318,
            longitude: -122.0312,
            radiusMeters: 150,
            startsOnArrival: true,
            stopsOnDeparture: true,
            isEnabled: true
        )

        guard let rule = viewModel.autoTickRules.first else {
            XCTFail("Expected an Auto Tick rule to update.")
            return
        }

        let didUpdate = await viewModel.updateAutoTickRule(
            id: rule.id,
            projectID: newProject.id,
            name: "  Studio Door  ",
            radiusMeters: 225,
            startsOnArrival: false,
            stopsOnDeparture: true,
            isEnabled: false
        )

        XCTAssertTrue(didUpdate)
        XCTAssertEqual(viewModel.autoTickRules.first?.name, "Studio Door")
        XCTAssertEqual(viewModel.autoTickRules.first?.projectID, newProject.id)
        XCTAssertEqual(viewModel.autoTickRules.first?.radiusMeters, 225)
        XCTAssertFalse(viewModel.autoTickRules.first?.startsOnArrival ?? true)
        XCTAssertTrue(viewModel.autoTickRules.first?.stopsOnDeparture ?? false)
        XCTAssertFalse(viewModel.autoTickRules.first?.isEnabled ?? true)
        XCTAssertEqual(viewModel.autoTickRules.first?.latitude, 37.3318)
        XCTAssertEqual(viewModel.autoTickRules.first?.longitude, -122.0312)

        let reloadedViewModel = TickViewModel(store: TickDataStore(fileURL: fileURL))
        await reloadedViewModel.loadIfNeeded()

        XCTAssertEqual(reloadedViewModel.autoTickRules.first?.name, "Studio Door")
        XCTAssertEqual(reloadedViewModel.autoTickRules.first?.projectID, newProject.id)
        XCTAssertEqual(reloadedViewModel.autoTickRules.first?.radiusMeters, 225)
        XCTAssertFalse(reloadedViewModel.autoTickRules.first?.startsOnArrival ?? true)
        XCTAssertTrue(reloadedViewModel.autoTickRules.first?.stopsOnDeparture ?? false)
        XCTAssertFalse(reloadedViewModel.autoTickRules.first?.isEnabled ?? true)
    }

    @MainActor
    func testViewModelDeletesAutoTickRuleAndPersists() async {
        let fileURL = temporaryStoreURL()
        defer {
            try? FileManager.default.removeItem(at: fileURL.deletingLastPathComponent())
        }

        let store = TickDataStore(fileURL: fileURL)
        let viewModel = TickViewModel(store: store)
        await viewModel.addProject(name: "Studio", createdAt: Date(timeIntervalSince1970: 0))
        let projectID = viewModel.activeProjects[0].id

        await viewModel.addAutoTickRule(
            projectID: projectID,
            name: "Office",
            latitude: 37.3318,
            longitude: -122.0312,
            radiusMeters: 150,
            startsOnArrival: true,
            stopsOnDeparture: true,
            isEnabled: true
        )

        guard let rule = viewModel.autoTickRules.first else {
            XCTFail("Expected an Auto Tick rule to delete.")
            return
        }

        let didDelete = await viewModel.deleteAutoTickRule(id: rule.id)

        XCTAssertTrue(didDelete)
        XCTAssertTrue(viewModel.autoTickRules.isEmpty)

        let reloadedViewModel = TickViewModel(store: TickDataStore(fileURL: fileURL))
        await reloadedViewModel.loadIfNeeded()

        XCTAssertTrue(reloadedViewModel.autoTickRules.isEmpty)
    }

    @MainActor
    func testInvalidAutoTickRuleUpdatesFailGracefully() async {
        let fileURL = temporaryStoreURL()
        defer {
            try? FileManager.default.removeItem(at: fileURL.deletingLastPathComponent())
        }

        let viewModel = TickViewModel(store: TickDataStore(fileURL: fileURL))
        await viewModel.addProject(name: "Studio", createdAt: Date(timeIntervalSince1970: 0))
        let projectID = viewModel.activeProjects[0].id

        await viewModel.addAutoTickRule(
            projectID: projectID,
            name: "Office",
            latitude: 37.3318,
            longitude: -122.0312,
            radiusMeters: 150,
            startsOnArrival: true,
            stopsOnDeparture: true,
            isEnabled: true
        )

        guard let originalRule = viewModel.autoTickRules.first else {
            XCTFail("Expected an Auto Tick rule to validate.")
            return
        }

        let missingProjectUpdate = await viewModel.updateAutoTickRule(
            id: originalRule.id,
            projectID: UUID(),
            name: "Office",
            radiusMeters: 150,
            startsOnArrival: true,
            stopsOnDeparture: true,
            isEnabled: true
        )
        let emptyNameUpdate = await viewModel.updateAutoTickRule(
            id: originalRule.id,
            projectID: projectID,
            name: "   ",
            radiusMeters: 150,
            startsOnArrival: true,
            stopsOnDeparture: true,
            isEnabled: true
        )
        let zeroRadiusUpdate = await viewModel.updateAutoTickRule(
            id: originalRule.id,
            projectID: projectID,
            name: "Office",
            radiusMeters: 0,
            startsOnArrival: true,
            stopsOnDeparture: true,
            isEnabled: true
        )
        let noBehaviorUpdate = await viewModel.updateAutoTickRule(
            id: originalRule.id,
            projectID: projectID,
            name: "Office",
            radiusMeters: 150,
            startsOnArrival: false,
            stopsOnDeparture: false,
            isEnabled: true
        )

        XCTAssertFalse(missingProjectUpdate)
        XCTAssertFalse(emptyNameUpdate)
        XCTAssertFalse(zeroRadiusUpdate)
        XCTAssertFalse(noBehaviorUpdate)
        XCTAssertEqual(viewModel.autoTickRules.first, originalRule)
        XCTAssertNotNil(viewModel.errorMessage)
    }

    @MainActor
    func testEnabledAutoTickArrivalStartsSession() async {
        let fileURL = temporaryStoreURL()
        defer {
            try? FileManager.default.removeItem(at: fileURL.deletingLastPathComponent())
        }

        let viewModel = TickViewModel(store: TickDataStore(fileURL: fileURL))
        await viewModel.addProject(name: "Studio", createdAt: Date(timeIntervalSince1970: 0))
        let projectID = viewModel.activeProjects[0].id

        await viewModel.addAutoTickRule(
            projectID: projectID,
            name: "Office",
            latitude: 37.3318,
            longitude: -122.0312,
            radiusMeters: 150,
            startsOnArrival: true,
            stopsOnDeparture: true,
            isEnabled: true,
            createdAt: Date(timeIntervalSince1970: 10)
        )

        let rule = viewModel.autoTickRules[0]
        let didStart = await viewModel.handleAutoTickEvent(
            ruleID: rule.id,
            event: .arrival,
            at: Date(timeIntervalSince1970: 100)
        )

        XCTAssertTrue(didStart)
        XCTAssertEqual(viewModel.activeSession?.entrySource, .autoLocation)
        XCTAssertEqual(viewModel.activeSession?.autoTickRuleID, rule.id)
        XCTAssertEqual(viewModel.activeSession?.projectID, projectID)
        XCTAssertEqual(viewModel.activeSession?.title, "Office")
    }

    @MainActor
    func testDisabledAutoTickArrivalDoesNothing() async {
        let fileURL = temporaryStoreURL()
        defer {
            try? FileManager.default.removeItem(at: fileURL.deletingLastPathComponent())
        }

        let viewModel = TickViewModel(store: TickDataStore(fileURL: fileURL))
        await viewModel.addProject(name: "Studio", createdAt: Date(timeIntervalSince1970: 0))

        await viewModel.addAutoTickRule(
            projectID: viewModel.activeProjects[0].id,
            name: "Office",
            latitude: 37.3318,
            longitude: -122.0312,
            radiusMeters: 150,
            startsOnArrival: true,
            stopsOnDeparture: true,
            isEnabled: false
        )

        let didStart = await viewModel.handleAutoTickEvent(
            ruleID: viewModel.autoTickRules[0].id,
            event: .arrival,
            at: Date(timeIntervalSince1970: 100)
        )

        XCTAssertFalse(didStart)
        XCTAssertTrue(viewModel.sessions.isEmpty)
    }

    @MainActor
    func testAutoTickArrivalDoesNotDuplicateActiveSession() async {
        let fileURL = temporaryStoreURL()
        defer {
            try? FileManager.default.removeItem(at: fileURL.deletingLastPathComponent())
        }

        let viewModel = TickViewModel(store: TickDataStore(fileURL: fileURL))
        await viewModel.addProject(name: "Studio", createdAt: Date(timeIntervalSince1970: 0))
        await viewModel.startTick(at: Date(timeIntervalSince1970: 50))

        await viewModel.addAutoTickRule(
            projectID: viewModel.activeProjects[0].id,
            name: "Office",
            latitude: 37.3318,
            longitude: -122.0312,
            radiusMeters: 150,
            startsOnArrival: true,
            stopsOnDeparture: true,
            isEnabled: true
        )

        let didStart = await viewModel.handleAutoTickEvent(
            ruleID: viewModel.autoTickRules[0].id,
            event: .arrival,
            at: Date(timeIntervalSince1970: 100)
        )

        XCTAssertFalse(didStart)
        XCTAssertEqual(viewModel.sessions.filter(\.isActive).count, 1)
        XCTAssertEqual(viewModel.activeSession?.entrySource, .timer)
    }

    @MainActor
    func testAutoTickDepartureStopsOnlyAssociatedAutoSession() async {
        let fileURL = temporaryStoreURL()
        defer {
            try? FileManager.default.removeItem(at: fileURL.deletingLastPathComponent())
        }

        let viewModel = TickViewModel(store: TickDataStore(fileURL: fileURL))
        await viewModel.addProject(name: "Studio", createdAt: Date(timeIntervalSince1970: 0))
        let projectID = viewModel.activeProjects[0].id
        await viewModel.addManualSession(
            projectID: projectID,
            title: "Manual",
            notes: "",
            date: Date(timeIntervalSince1970: 20),
            duration: 600
        )

        await viewModel.addAutoTickRule(
            projectID: projectID,
            name: "Office",
            latitude: 37.3318,
            longitude: -122.0312,
            radiusMeters: 150,
            startsOnArrival: true,
            stopsOnDeparture: true,
            isEnabled: true,
            createdAt: Date(timeIntervalSince1970: 30)
        )
        await viewModel.addAutoTickRule(
            projectID: projectID,
            name: "Workshop",
            latitude: 37.332,
            longitude: -122.032,
            radiusMeters: 150,
            startsOnArrival: true,
            stopsOnDeparture: true,
            isEnabled: true,
            createdAt: Date(timeIntervalSince1970: 40)
        )

        let officeRule = viewModel.autoTickRules[0]
        let workshopRule = viewModel.autoTickRules[1]
        await viewModel.handleAutoTickEvent(
            ruleID: officeRule.id,
            event: .arrival,
            at: Date(timeIntervalSince1970: 100)
        )

        let didStopWrongRule = await viewModel.handleAutoTickEvent(
            ruleID: workshopRule.id,
            event: .departure,
            at: Date(timeIntervalSince1970: 200)
        )
        XCTAssertFalse(didStopWrongRule)
        XCTAssertTrue(viewModel.activeSession?.isActive == true)

        let didStopOffice = await viewModel.handleAutoTickEvent(
            ruleID: officeRule.id,
            event: .departure,
            at: Date(timeIntervalSince1970: 300)
        )

        XCTAssertTrue(didStopOffice)
        XCTAssertNil(viewModel.activeSession)
        XCTAssertEqual(viewModel.sessions.first(where: { $0.entrySource == .manual })?.duration(), 600)
        XCTAssertEqual(viewModel.sessions.first(where: { $0.autoTickRuleID == officeRule.id })?.endedAt, Date(timeIntervalSince1970: 300))
    }

    func testDeniedAutoTickLocationPermissionIsNonTrackingState() {
        let status = AutoTickLocationAuthorizationStatus.denied

        XCTAssertFalse(status.canRequestCurrentLocation)
        XCTAssertFalse(status.canMonitorRegions)
        XCTAssertFalse(status.needsPermissionRequest)
        XCTAssertTrue(status.displayText.contains("denied"))
    }

    private func temporaryStoreURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent("tick-data.json")
    }
}

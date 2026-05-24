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

    func testICloudResolutionUsesNewerRemoteSnapshot() {
        let project = TickProject(name: "Synced", createdAt: Date(timeIntervalSince1970: 100))
        let localSnapshot = TickStorageSnapshot.empty
        let remoteSnapshot = TickStorageSnapshot(projects: [project], sessions: [])
        let syncStore = TickICloudSyncStore()

        let resolution = syncStore.resolve(
            localSnapshot: localSnapshot,
            localModifiedAt: Date(timeIntervalSince1970: 100),
            remoteEnvelope: (
                snapshot: remoteSnapshot,
                updatedAt: Date(timeIntervalSince1970: 200)
            )
        )

        XCTAssertEqual(resolution.snapshot, remoteSnapshot)
        XCTAssertTrue(resolution.shouldSaveLocal)
        XCTAssertFalse(resolution.shouldSaveRemote)
    }

    func testICloudResolutionPushesNewerLocalSnapshot() {
        let project = TickProject(name: "Local", createdAt: Date(timeIntervalSince1970: 100))
        let localSnapshot = TickStorageSnapshot(projects: [project], sessions: [])
        let remoteSnapshot = TickStorageSnapshot.empty
        let syncStore = TickICloudSyncStore()

        let resolution = syncStore.resolve(
            localSnapshot: localSnapshot,
            localModifiedAt: Date(timeIntervalSince1970: 300),
            remoteEnvelope: (
                snapshot: remoteSnapshot,
                updatedAt: Date(timeIntervalSince1970: 200)
            )
        )

        XCTAssertEqual(resolution.snapshot, localSnapshot)
        XCTAssertFalse(resolution.shouldSaveLocal)
        XCTAssertTrue(resolution.shouldSaveRemote)
    }

    func testStorageSnapshotDefaultsMissingAutoTickRules() throws {
        let data = Data(#"{"projects":[],"sessions":[]}"#.utf8)

        let snapshot = try JSONDecoder().decode(TickStorageSnapshot.self, from: data)

        XCTAssertTrue(snapshot.autoTickRules.isEmpty)
    }

    func testProjectAccentAssignmentIsStable() {
        let projectID = UUID(uuidString: "00000000-0000-0000-0000-000000000123")!

        XCTAssertEqual(TickProjectAccent.index(for: projectID.uuidString), TickProjectAccent.index(for: projectID.uuidString))
        XCTAssertEqual(TickProjectAccent.index(for: "PiSignage"), TickProjectAccent.index(for: "PiSignage"))
    }

    @MainActor
    func testProjectAccentAssignmentDistributesSampleProjects() {
        let sampleProjectNames = ["PiSignage", "Earth Pulse", "Coloring Room", "Briefly"]
        let accentIndexes = Set(sampleProjectNames.map(TickProjectAccent.index(for:)))

        XCTAssertEqual(accentIndexes.count, sampleProjectNames.count)
    }

    @MainActor
    func testSessionsForProjectFiltersAndSortsNewestFirst() async {
        let fileURL = temporaryStoreURL()
        defer {
            try? FileManager.default.removeItem(at: fileURL.deletingLastPathComponent())
        }

        let viewModel = TickViewModel(store: TickDataStore(fileURL: fileURL))
        await viewModel.addProject(name: "First", createdAt: Date(timeIntervalSince1970: 0))
        await viewModel.addProject(name: "Second", createdAt: Date(timeIntervalSince1970: 1))
        let firstProjectID = viewModel.activeProjects[0].id
        let secondProjectID = viewModel.activeProjects[1].id

        await viewModel.addManualSession(
            projectID: firstProjectID,
            title: "Old",
            notes: "",
            date: Date(timeIntervalSince1970: 100),
            duration: 300
        )
        await viewModel.addManualSession(
            projectID: secondProjectID,
            title: "Other",
            notes: "",
            date: Date(timeIntervalSince1970: 200),
            duration: 300
        )
        await viewModel.addManualSession(
            projectID: firstProjectID,
            title: "New",
            notes: "",
            date: Date(timeIntervalSince1970: 300),
            duration: 300
        )

        let projectSessions = viewModel.sessions(for: firstProjectID)

        XCTAssertEqual(projectSessions.map(\.title), ["New", "Old"])
        XCTAssertTrue(projectSessions.allSatisfy { $0.projectID == firstProjectID })
    }

    @MainActor
    func testDeleteSessionRemovesPersistedSession() async {
        let fileURL = temporaryStoreURL()
        defer {
            try? FileManager.default.removeItem(at: fileURL.deletingLastPathComponent())
        }

        let store = TickDataStore(fileURL: fileURL)
        let viewModel = TickViewModel(store: store)
        await viewModel.addProject(name: "Studio", createdAt: Date(timeIntervalSince1970: 0))
        let projectID = viewModel.activeProjects[0].id
        await viewModel.addManualSession(
            projectID: projectID,
            title: "Planning",
            notes: "",
            date: Date(timeIntervalSince1970: 100),
            duration: 1_200
        )

        guard let sessionID = viewModel.sessions.first?.id else {
            XCTFail("Expected a session to delete.")
            return
        }

        let didDelete = await viewModel.deleteSession(id: sessionID)
        let reloadedViewModel = TickViewModel(store: TickDataStore(fileURL: fileURL))
        await reloadedViewModel.loadIfNeeded()

        XCTAssertTrue(didDelete)
        XCTAssertTrue(viewModel.sessions.isEmpty)
        XCTAssertTrue(reloadedViewModel.sessions.isEmpty)
    }

    @MainActor
    func testDeletingSessionUpdatesProjectTotalDuration() async {
        let fileURL = temporaryStoreURL()
        defer {
            try? FileManager.default.removeItem(at: fileURL.deletingLastPathComponent())
        }

        let viewModel = TickViewModel(store: TickDataStore(fileURL: fileURL))
        await viewModel.addProject(name: "Studio", createdAt: Date(timeIntervalSince1970: 0))
        let projectID = viewModel.activeProjects[0].id

        await viewModel.addManualSession(
            projectID: projectID,
            title: "Keep",
            notes: "",
            date: Date(timeIntervalSince1970: 100),
            duration: 600
        )
        await viewModel.addManualSession(
            projectID: projectID,
            title: "Delete",
            notes: "",
            date: Date(timeIntervalSince1970: 200),
            duration: 900
        )

        guard let sessionID = viewModel.sessions.first(where: { $0.title == "Delete" })?.id else {
            XCTFail("Expected a session to delete.")
            return
        }

        XCTAssertEqual(viewModel.totalDuration(for: projectID), 1_500)

        let didDelete = await viewModel.deleteSession(id: sessionID)

        XCTAssertTrue(didDelete)
        XCTAssertEqual(viewModel.totalDuration(for: projectID), 600)
    }

    @MainActor
    func testDeletingActiveSessionIsBlocked() async {
        let fileURL = temporaryStoreURL()
        defer {
            try? FileManager.default.removeItem(at: fileURL.deletingLastPathComponent())
        }

        let viewModel = TickViewModel(store: TickDataStore(fileURL: fileURL))
        await viewModel.addProject(name: "Studio", createdAt: Date(timeIntervalSince1970: 0))
        await viewModel.startTick(at: Date(timeIntervalSince1970: 100))

        guard let activeSessionID = viewModel.activeSession?.id else {
            XCTFail("Expected an active session.")
            return
        }

        let didDelete = await viewModel.deleteSession(id: activeSessionID)

        XCTAssertFalse(didDelete)
        XCTAssertEqual(viewModel.sessions.count, 1)
        XCTAssertEqual(viewModel.activeSession?.id, activeSessionID)
        XCTAssertEqual(viewModel.errorMessage, "Stop the active Tick before deleting it.")
    }

    func testWidgetSnapshotGenerationWithNoProjects() {
        let snapshot = TickWidgetSnapshotBuilder.snapshot(
            from: .empty,
            defaultProjectID: nil,
            at: Date(timeIntervalSince1970: 100)
        )

        XCTAssertFalse(snapshot.hasProjects)
        XCTAssertNil(snapshot.defaultProjectID)
        XCTAssertNil(snapshot.activeSessionID)
        XCTAssertEqual(snapshot.todayTotalDuration, 0)
    }

    func testWidgetSnapshotGenerationWithNoActiveSession() {
        let project = TickWidgetStoredProject(
            id: UUID(),
            name: "Studio",
            createdAt: Date(timeIntervalSince1970: 0),
            isArchived: false
        )
        let session = TickWidgetStoredSession(
            id: UUID(),
            projectID: project.id,
            title: "Planning",
            notes: "",
            startedAt: Date(timeIntervalSince1970: 100),
            endedAt: Date(timeIntervalSince1970: 1_000),
            manualDuration: nil,
            entrySource: "timer",
            autoTickRuleID: nil,
            createdAt: Date(timeIntervalSince1970: 100)
        )
        let snapshot = TickWidgetSnapshotBuilder.snapshot(
            from: TickWidgetStorageSnapshot(projects: [project], sessions: [session]),
            defaultProjectID: project.id,
            at: Date(timeIntervalSince1970: 1_200)
        )

        XCTAssertTrue(snapshot.hasProjects)
        XCTAssertEqual(snapshot.defaultProjectID, project.id)
        XCTAssertEqual(snapshot.defaultProjectName, "Studio")
        XCTAssertNil(snapshot.activeSessionID)
        XCTAssertEqual(snapshot.todayTotalDuration, 900)
    }

    func testWidgetSnapshotGenerationWithActiveSession() {
        let project = TickWidgetStoredProject(
            id: UUID(),
            name: "Studio",
            createdAt: Date(timeIntervalSince1970: 0),
            isArchived: false
        )
        let activeSession = TickWidgetStoredSession(
            id: UUID(),
            projectID: project.id,
            title: "",
            notes: "",
            startedAt: Date(timeIntervalSince1970: 100),
            endedAt: nil,
            manualDuration: nil,
            entrySource: "timer",
            autoTickRuleID: nil,
            createdAt: Date(timeIntervalSince1970: 100)
        )
        let snapshot = TickWidgetSnapshotBuilder.snapshot(
            from: TickWidgetStorageSnapshot(projects: [project], sessions: [activeSession]),
            defaultProjectID: nil,
            at: Date(timeIntervalSince1970: 700)
        )

        XCTAssertEqual(snapshot.activeSessionID, activeSession.id)
        XCTAssertEqual(snapshot.activeProjectName, "Studio")
        XCTAssertEqual(snapshot.activeSessionTitle, "1 Tick")
        XCTAssertEqual(snapshot.activeStartedAt, Date(timeIntervalSince1970: 100))
        XCTAssertEqual(snapshot.todayTotalDuration, 600)
    }

    func testAccessoryRectangularNoProjectContent() {
        let content = TickAccessoryWidgetContentBuilder.content(
            from: .empty(lastUpdatedAt: Date(timeIntervalSince1970: 100)),
            at: Date(timeIntervalSince1970: 100)
        )

        XCTAssertEqual(content.state, .noProjects)
        XCTAssertEqual(content.rectangularTitle, "Ticks")
        XCTAssertEqual(content.rectangularDetail, "Create a project")
        XCTAssertEqual(content.circularText, "0")
        XCTAssertEqual(content.inlineText, "Ticks: create a project")
    }

    func testAccessoryRectangularIdleContent() {
        let snapshot = TickWidgetSnapshot(
            hasProjects: true,
            defaultProjectID: UUID(),
            defaultProjectName: "Studio",
            activeSessionID: nil,
            activeProjectName: nil,
            activeSessionTitle: nil,
            activeStartedAt: nil,
            todayTotalDuration: 4_800,
            lastUpdatedAt: Date(timeIntervalSince1970: 100)
        )
        let content = TickAccessoryWidgetContentBuilder.content(
            from: snapshot,
            at: Date(timeIntervalSince1970: 100)
        )

        XCTAssertEqual(content.state, .idle)
        XCTAssertEqual(content.rectangularTitle, "Ticks")
        XCTAssertEqual(content.rectangularDetail, "1h 20m")
        XCTAssertEqual(content.rectangularFootnote, "Studio")
        XCTAssertEqual(content.inlineText, "Ticks: 1h 20m today")
    }

    func testAccessoryRectangularActiveContent() {
        let snapshot = TickWidgetSnapshot(
            hasProjects: true,
            defaultProjectID: nil,
            defaultProjectName: nil,
            activeSessionID: UUID(),
            activeProjectName: "PiSignage",
            activeSessionTitle: "1 Tick",
            activeStartedAt: Date(timeIntervalSince1970: 100),
            todayTotalDuration: 2_520,
            lastUpdatedAt: Date(timeIntervalSince1970: 100)
        )
        let content = TickAccessoryWidgetContentBuilder.content(
            from: snapshot,
            at: Date(timeIntervalSince1970: 2_620)
        )

        XCTAssertEqual(content.state, .active)
        XCTAssertEqual(content.rectangularTitle, "PiSignage")
        XCTAssertEqual(content.rectangularDetail, "42m")
        XCTAssertEqual(content.rectangularFootnote, "Running")
        XCTAssertEqual(content.inlineText, "PiSignage running 42m")
    }

    func testAccessoryCircularIdleAndActiveContent() {
        let idleSnapshot = TickWidgetSnapshot(
            hasProjects: true,
            defaultProjectID: UUID(),
            defaultProjectName: "Studio",
            activeSessionID: nil,
            activeProjectName: nil,
            activeSessionTitle: nil,
            activeStartedAt: nil,
            todayTotalDuration: 900,
            lastUpdatedAt: Date(timeIntervalSince1970: 100)
        )
        let activeSnapshot = TickWidgetSnapshot(
            hasProjects: true,
            defaultProjectID: nil,
            defaultProjectName: nil,
            activeSessionID: UUID(),
            activeProjectName: "Studio",
            activeSessionTitle: nil,
            activeStartedAt: Date(timeIntervalSince1970: 100),
            todayTotalDuration: 7_200,
            lastUpdatedAt: Date(timeIntervalSince1970: 100)
        )

        let idleContent = TickAccessoryWidgetContentBuilder.content(
            from: idleSnapshot,
            at: Date(timeIntervalSince1970: 100)
        )
        let activeContent = TickAccessoryWidgetContentBuilder.content(
            from: activeSnapshot,
            at: Date(timeIntervalSince1970: 7_300)
        )

        XCTAssertEqual(idleContent.circularText, "15m")
        XCTAssertEqual(idleContent.circularSystemImage, "timer")
        XCTAssertEqual(activeContent.circularText, "2h 0m")
        XCTAssertEqual(activeContent.circularSystemImage, "timer")
    }

    func testWidgetStartDoesNotCreateDuplicateActiveSessions() async throws {
        let urls = temporaryWidgetStoreURLs()
        defer {
            try? FileManager.default.removeItem(at: urls.directoryURL)
        }

        let project = TickWidgetStoredProject(
            id: UUID(),
            name: "Studio",
            createdAt: Date(timeIntervalSince1970: 0),
            isArchived: false
        )
        let activeSession = TickWidgetStoredSession(
            id: UUID(),
            projectID: project.id,
            title: "",
            notes: "",
            startedAt: Date(timeIntervalSince1970: 100),
            endedAt: nil,
            manualDuration: nil,
            entrySource: "timer",
            autoTickRuleID: nil,
            createdAt: Date(timeIntervalSince1970: 100)
        )
        let store = TickWidgetActionStore(
            dataFileURL: urls.dataFileURL,
            widgetSnapshotFileURL: urls.snapshotFileURL
        )

        try await seedWidgetStore(
            TickWidgetStorageSnapshot(projects: [project], sessions: [activeSession]),
            at: urls.dataFileURL
        )

        let result = try store.startTick(at: Date(timeIntervalSince1970: 200))
        let savedSnapshot = try store.loadStorageSnapshot()

        XCTAssertFalse(result.didChange)
        XCTAssertEqual(savedSnapshot.sessions.filter(\.isActive).count, 1)
        XCTAssertEqual(savedSnapshot.sessions.first?.id, activeSession.id)
    }

    func testWidgetStopStopsOnlyActiveSession() async throws {
        let urls = temporaryWidgetStoreURLs()
        defer {
            try? FileManager.default.removeItem(at: urls.directoryURL)
        }

        let project = TickWidgetStoredProject(
            id: UUID(),
            name: "Studio",
            createdAt: Date(timeIntervalSince1970: 0),
            isArchived: false
        )
        let activeSession = TickWidgetStoredSession(
            id: UUID(),
            projectID: project.id,
            title: "",
            notes: "",
            startedAt: Date(timeIntervalSince1970: 100),
            endedAt: nil,
            manualDuration: nil,
            entrySource: "timer",
            autoTickRuleID: nil,
            createdAt: Date(timeIntervalSince1970: 100)
        )
        let manualSession = TickWidgetStoredSession(
            id: UUID(),
            projectID: project.id,
            title: "Manual",
            notes: "",
            startedAt: Date(timeIntervalSince1970: 50),
            endedAt: nil,
            manualDuration: 600,
            entrySource: "manual",
            autoTickRuleID: nil,
            createdAt: Date(timeIntervalSince1970: 50)
        )
        let store = TickWidgetActionStore(
            dataFileURL: urls.dataFileURL,
            widgetSnapshotFileURL: urls.snapshotFileURL
        )

        try await seedWidgetStore(
            TickWidgetStorageSnapshot(projects: [project], sessions: [manualSession, activeSession]),
            at: urls.dataFileURL
        )

        let result = try store.stopTick(at: Date(timeIntervalSince1970: 300))
        let savedSnapshot = try store.loadStorageSnapshot()

        XCTAssertTrue(result.didChange)
        XCTAssertNil(savedSnapshot.sessions.first { $0.id == activeSession.id }?.manualDuration)
        XCTAssertEqual(savedSnapshot.sessions.first { $0.id == activeSession.id }?.endedAt, Date(timeIntervalSince1970: 300))
        XCTAssertEqual(savedSnapshot.sessions.first { $0.id == manualSession.id }?.manualDuration, 600)
        XCTAssertFalse(savedSnapshot.sessions.contains(where: \.isActive))
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

    private func temporaryWidgetStoreURLs() -> (
        directoryURL: URL,
        dataFileURL: URL,
        snapshotFileURL: URL
    ) {
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)

        return (
            directoryURL,
            directoryURL.appendingPathComponent("tick-data.json"),
            directoryURL.appendingPathComponent("tick-widget-snapshot.json")
        )
    }

    private func seedWidgetStore(_ snapshot: TickWidgetStorageSnapshot, at fileURL: URL) async throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let data = try encoder.encode(snapshot)
        try data.write(to: fileURL, options: [.atomic])
    }
}

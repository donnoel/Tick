import XCTest
@testable import Tick

final class TickTests: XCTestCase {
    func testProjectAccentAssignmentUsesVisibleProjectOrderForUniqueColors() {
        let projectIDs = [
            UUID(uuidString: "00000000-0000-0000-0000-000000000101")!,
            UUID(uuidString: "00000000-0000-0000-0000-000000000102")!,
            UUID(uuidString: "00000000-0000-0000-0000-000000000103")!,
            UUID(uuidString: "00000000-0000-0000-0000-000000000104")!
        ]

        XCTAssertEqual(
            projectIDs.map { TickProjectAccent.index(for: $0, among: projectIDs) },
            [0, 1, 2, 3]
        )
    }

    func testProjectAccentResolvesPaletteCollisionsWithinProjectSet() {
        var projectIDsByAccentIndex: [Int: TickProject.ID] = [:]
        var collidingProjectIDs: [TickProject.ID] = []

        for value in 0..<1_000 {
            let projectID = UUID(uuidString: String(format: "00000000-0000-0000-0000-%012X", value))!
            let accentIndex = TickProjectAccent.index(for: projectID)

            if let existingProjectID = projectIDsByAccentIndex[accentIndex] {
                collidingProjectIDs = [existingProjectID, projectID]
                break
            }

            projectIDsByAccentIndex[accentIndex] = projectID
        }

        XCTAssertEqual(collidingProjectIDs.count, 2)
        XCTAssertEqual(
            Set(collidingProjectIDs.map { TickProjectAccent.index(for: $0, among: collidingProjectIDs) }).count,
            collidingProjectIDs.count
        )
    }

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

    func testProjectChartExcludesZeroDurationProjects() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!

        let referenceDate = Date(timeIntervalSince1970: 1_700_000_000)
        let zeroDurationProject = TickProject(id: UUID(), name: "Zero", createdAt: referenceDate)
        let trackedProject = TickProject(id: UUID(), name: "Tracked", createdAt: referenceDate)
        let trackedSession = TimeSession(
            projectID: trackedProject.id,
            title: "",
            notes: "",
            startedAt: referenceDate,
            endedAt: referenceDate.addingTimeInterval(3_600),
            manualDuration: nil,
            entrySource: .timer
        )

        let entries = TickChartDataBuilder.projectEntries(
            for: .day,
            projects: [zeroDurationProject, trackedProject],
            sessions: [trackedSession],
            referenceDate: referenceDate,
            calendar: calendar
        )

        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?.projectID, trackedProject.id)
    }

    func testProjectChartIncludesArchivedProjectWithTime() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!

        let referenceDate = Date(timeIntervalSince1970: 1_700_000_000)
        let archivedProject = TickProject(
            id: UUID(),
            name: "Archived",
            createdAt: referenceDate,
            isArchived: true
        )
        let session = TimeSession(
            projectID: archivedProject.id,
            title: "",
            notes: "",
            startedAt: referenceDate,
            endedAt: referenceDate.addingTimeInterval(1_800),
            manualDuration: nil,
            entrySource: .timer
        )

        let entries = TickChartDataBuilder.projectEntries(
            for: .day,
            projects: [archivedProject],
            sessions: [session],
            referenceDate: referenceDate,
            calendar: calendar
        )

        XCTAssertEqual(entries.map(\.projectID), [archivedProject.id])
    }

    func testWeeklyDayChartReturnsSevenOrderedDays() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        calendar.firstWeekday = 2

        let referenceDate = Date(timeIntervalSince1970: 1_700_000_000)

        let entries = TickChartDataBuilder.dayEntries(
            for: .week,
            sessions: [],
            referenceDate: referenceDate,
            calendar: calendar
        )

        XCTAssertEqual(entries.count, 7)
        XCTAssertTrue(zip(entries, entries.dropFirst()).allSatisfy { lhs, rhs in
            lhs.date < rhs.date
        })
    }

    func testMonthlyDayChartReturnsOrderedDaysForMonth() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let referenceDate = Date(timeIntervalSince1970: 1_709_251_200) // 2024-03-15 00:00:00 UTC

        let entries = TickChartDataBuilder.dayEntries(
            for: .month,
            sessions: [],
            referenceDate: referenceDate,
            calendar: calendar
        )

        XCTAssertEqual(entries.count, 31)
        XCTAssertTrue(zip(entries, entries.dropFirst()).allSatisfy { lhs, rhs in
            lhs.date < rhs.date
        })
    }

    func testDayProjectChartKeepsProjectIdentity() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        calendar.firstWeekday = 2

        let referenceDate = Date(timeIntervalSince1970: 1_700_000_000)
        let projectA = TickProject(id: UUID(), name: "Alpha", createdAt: referenceDate)
        let projectB = TickProject(id: UUID(), name: "Beta", createdAt: referenceDate)
        let sessionA = TimeSession(
            projectID: projectA.id,
            title: "",
            notes: "",
            startedAt: nil,
            endedAt: nil,
            manualDuration: 1_800,
            entrySource: .manual,
            createdAt: referenceDate
        )
        let sessionB = TimeSession(
            projectID: projectB.id,
            title: "",
            notes: "",
            startedAt: nil,
            endedAt: nil,
            manualDuration: 3_600,
            entrySource: .manual,
            createdAt: referenceDate
        )

        let entries = TickChartDataBuilder.dayProjectEntries(
            for: .week,
            projects: [projectB, projectA],
            sessions: [sessionB, sessionA],
            referenceDate: referenceDate,
            calendar: calendar
        )

        XCTAssertEqual(entries.map(\.projectID), [projectA.id, projectB.id])
        XCTAssertEqual(entries.map(\.duration), [1_800, 3_600])
    }

    func testActiveRunningSessionContributesChartDurationAtDisplayDate() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!

        let project = TickProject(id: UUID(), name: "Active", createdAt: Date(timeIntervalSince1970: 0))
        let startDate = Date(timeIntervalSince1970: 1_700_000_000)
        let displayDate = startDate.addingTimeInterval(1_800)
        let activeSession = TimeSession(
            projectID: project.id,
            title: "",
            notes: "",
            startedAt: startDate,
            endedAt: nil,
            manualDuration: nil,
            entrySource: .timer
        )

        let projectEntries = TickChartDataBuilder.projectEntries(
            for: .day,
            projects: [project],
            sessions: [activeSession],
            referenceDate: displayDate,
            calendar: calendar
        )
        let dayEntries = TickChartDataBuilder.dayEntries(
            for: .week,
            sessions: [activeSession],
            referenceDate: displayDate,
            calendar: calendar
        )

        XCTAssertEqual(projectEntries.first?.duration ?? 0, 1_800, accuracy: 0.1)
        XCTAssertEqual(dayEntries.reduce(0) { $0 + $1.duration }, 1_800, accuracy: 0.1)
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

    func testProjectDecodingDefaultsMissingSortOrderToCreatedDate() throws {
        let data = Data(
            #"""
            {
                "id": "00000000-0000-0000-0000-000000000111",
                "name": "Legacy",
                "createdAt": "1970-01-01T00:00:10Z",
                "isArchived": false
            }
            """#.utf8
        )
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let project = try decoder.decode(TickProject.self, from: data)

        XCTAssertEqual(project.sortOrder, project.createdAt.timeIntervalSinceReferenceDate)
    }

    func testProjectsSortByActivityThenManualDisplayOrder() {
        let olderProject = TickProject(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000201")!,
            name: "Older",
            createdAt: Date(timeIntervalSince1970: 0),
            sortOrder: 1
        )
        let mostActiveProject = TickProject(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000202")!,
            name: "Most Active",
            createdAt: Date(timeIntervalSince1970: 1),
            sortOrder: 2
        )
        let tiedProject = TickProject(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000203")!,
            name: "Tied",
            createdAt: Date(timeIntervalSince1970: 2),
            sortOrder: 3
        )

        let sortedProjects = TickProject.sortedByActivity(
            [tiedProject, mostActiveProject, olderProject],
            durationsByProjectID: [
                olderProject.id: 600,
                mostActiveProject.id: 1_200,
                tiedProject.id: 600
            ]
        )

        XCTAssertEqual(
            sortedProjects.map(\.id),
            [mostActiveProject.id, olderProject.id, tiedProject.id]
        )
    }

    func testVoiceMemoStoreRoundTripsMetadataAndDeletesAudioFile() async throws {
        let urls = temporaryVoiceMemoStoreURLs()
        defer {
            try? FileManager.default.removeItem(at: urls.directoryURL)
        }

        let projectID = UUID()
        let voiceMemo = VoiceMemo(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000321")!,
            projectID: projectID,
            title: "Planning note",
            duration: 42,
            createdAt: Date(timeIntervalSince1970: 1_000)
        )
        let store = TickVoiceMemoStore(
            metadataFileURL: urls.metadataFileURL,
            voiceMemoDirectoryURL: urls.audioDirectoryURL,
            usesICloud: false
        )

        let audioURL = try await store.preparedFileURL(for: voiceMemo.fileName)
        try Data([1, 2, 3]).write(to: audioURL)
        try await store.save([voiceMemo])
        let loadedVoiceMemos = try await store.load()

        XCTAssertEqual(loadedVoiceMemos, [voiceMemo])
        XCTAssertTrue(FileManager.default.fileExists(atPath: audioURL.path))

        try await store.deleteAudioFile(for: voiceMemo)

        XCTAssertFalse(FileManager.default.fileExists(atPath: audioURL.path))
    }

    @MainActor
    func testDeletingProjectRemovesProjectVoiceMemosAndAudioFiles() async throws {
        let dataFileURL = temporaryStoreURL()
        let voiceMemoURLs = temporaryVoiceMemoStoreURLs()
        defer {
            try? FileManager.default.removeItem(at: dataFileURL.deletingLastPathComponent())
            try? FileManager.default.removeItem(at: voiceMemoURLs.directoryURL)
        }

        let project = TickProject(name: "Studio", createdAt: Date(timeIntervalSince1970: 10))
        let voiceMemo = VoiceMemo(
            projectID: project.id,
            title: "Client thought",
            fileName: "client-thought.m4a",
            duration: 12,
            createdAt: Date(timeIntervalSince1970: 20)
        )
        let dataStore = TickDataStore(fileURL: dataFileURL)
        let voiceMemoStore = TickVoiceMemoStore(
            metadataFileURL: voiceMemoURLs.metadataFileURL,
            voiceMemoDirectoryURL: voiceMemoURLs.audioDirectoryURL,
            usesICloud: false
        )

        try await dataStore.save(TickStorageSnapshot(projects: [project], sessions: []))
        try await voiceMemoStore.save([voiceMemo])
        let audioURL = try await voiceMemoStore.preparedFileURL(for: voiceMemo.fileName)
        try Data([4, 5, 6]).write(to: audioURL)

        let viewModel = TickViewModel(store: dataStore, voiceMemoStore: voiceMemoStore)
        await viewModel.loadIfNeeded()

        XCTAssertEqual(viewModel.voiceMemos(for: project.id), [voiceMemo])

        let didDelete = await viewModel.deleteProject(id: project.id)

        XCTAssertTrue(didDelete)
        XCTAssertTrue(viewModel.voiceMemos(for: project.id).isEmpty)
        let loadedVoiceMemos = try await voiceMemoStore.load()
        XCTAssertTrue(loadedVoiceMemos.isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: audioURL.path))
    }

    @MainActor
    func testRenamingVoiceMemoPersistsTrimmedTitle() async throws {
        let dataFileURL = temporaryStoreURL()
        let voiceMemoURLs = temporaryVoiceMemoStoreURLs()
        defer {
            try? FileManager.default.removeItem(at: dataFileURL.deletingLastPathComponent())
            try? FileManager.default.removeItem(at: voiceMemoURLs.directoryURL)
        }

        let project = TickProject(name: "Studio", createdAt: Date(timeIntervalSince1970: 10))
        let voiceMemo = VoiceMemo(
            projectID: project.id,
            title: "Voice memo",
            fileName: "voice-memo.m4a",
            duration: 12,
            createdAt: Date(timeIntervalSince1970: 20)
        )
        let dataStore = TickDataStore(fileURL: dataFileURL)
        let voiceMemoStore = TickVoiceMemoStore(
            metadataFileURL: voiceMemoURLs.metadataFileURL,
            voiceMemoDirectoryURL: voiceMemoURLs.audioDirectoryURL,
            usesICloud: false
        )

        try await dataStore.save(TickStorageSnapshot(projects: [project], sessions: []))
        try await voiceMemoStore.save([voiceMemo])

        let viewModel = TickViewModel(store: dataStore, voiceMemoStore: voiceMemoStore)
        await viewModel.loadIfNeeded()

        let didRename = await viewModel.updateVoiceMemoTitle(id: voiceMemo.id, title: "  Client notes  ")

        XCTAssertTrue(didRename)
        XCTAssertEqual(viewModel.voiceMemos(for: project.id).first?.title, "Client notes")
        let loadedVoiceMemos = try await voiceMemoStore.load()
        XCTAssertEqual(loadedVoiceMemos.first?.title, "Client notes")
    }

    func testVoiceMemoStoreCopiesLocalMetadataAndAudioToICloudStore() async throws {
        let urls = temporaryVoiceMemoStoreURLs()
        defer {
            try? FileManager.default.removeItem(at: urls.directoryURL)
        }

        let voiceMemo = VoiceMemo(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000654")!,
            projectID: UUID(),
            title: "Local memo",
            duration: 42,
            createdAt: Date(timeIntervalSince1970: 1_000)
        )
        let store = TickVoiceMemoStore(
            metadataFileURL: urls.metadataFileURL,
            voiceMemoDirectoryURL: urls.audioDirectoryURL,
            iCloudMetadataFileURL: urls.iCloudMetadataFileURL,
            iCloudVoiceMemoDirectoryURL: urls.iCloudAudioDirectoryURL
        )

        let localAudioURL = try await store.preparedFileURL(for: voiceMemo.fileName)
        try Data([1, 2, 3]).write(to: localAudioURL)
        try await store.save([voiceMemo])

        let loadedVoiceMemos = try await store.load()
        let iCloudAudioURL = urls.iCloudAudioDirectoryURL.appendingPathComponent(voiceMemo.fileName)
        let iCloudSnapshot = try decodeVoiceMemoSnapshot(at: urls.iCloudMetadataFileURL)

        XCTAssertEqual(loadedVoiceMemos, [voiceMemo])
        XCTAssertEqual(iCloudSnapshot.voiceMemos, [voiceMemo])
        XCTAssertTrue(FileManager.default.fileExists(atPath: iCloudAudioURL.path))
    }

    func testVoiceMemoStoreCopiesICloudMetadataAndAudioToLocalStore() async throws {
        let urls = temporaryVoiceMemoStoreURLs()
        defer {
            try? FileManager.default.removeItem(at: urls.directoryURL)
        }

        let voiceMemo = VoiceMemo(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000655")!,
            projectID: UUID(),
            title: "Remote memo",
            duration: 42,
            createdAt: Date(timeIntervalSince1970: 1_000)
        )
        let iCloudAudioURL = urls.iCloudAudioDirectoryURL.appendingPathComponent(voiceMemo.fileName)
        try FileManager.default.createDirectory(at: urls.iCloudAudioDirectoryURL, withIntermediateDirectories: true)
        try Data([4, 5, 6]).write(to: iCloudAudioURL)
        try encodeVoiceMemoSnapshot(
            TickVoiceMemoStorageSnapshot(voiceMemos: [voiceMemo]),
            at: urls.iCloudMetadataFileURL
        )
        let store = TickVoiceMemoStore(
            metadataFileURL: urls.metadataFileURL,
            voiceMemoDirectoryURL: urls.audioDirectoryURL,
            iCloudMetadataFileURL: urls.iCloudMetadataFileURL,
            iCloudVoiceMemoDirectoryURL: urls.iCloudAudioDirectoryURL
        )

        let loadedVoiceMemos = try await store.load()
        let localAudioURL = urls.audioDirectoryURL.appendingPathComponent(voiceMemo.fileName)
        let localSnapshot = try decodeVoiceMemoSnapshot(at: urls.metadataFileURL)

        XCTAssertEqual(loadedVoiceMemos, [voiceMemo])
        XCTAssertEqual(localSnapshot.voiceMemos, [voiceMemo])
        XCTAssertTrue(FileManager.default.fileExists(atPath: localAudioURL.path))
    }

    func testVoiceMemoStoreDeletionTombstoneWinsOverOlderICloudMemo() async throws {
        let urls = temporaryVoiceMemoStoreURLs()
        defer {
            try? FileManager.default.removeItem(at: urls.directoryURL)
        }

        let voiceMemoID = UUID(uuidString: "00000000-0000-0000-0000-000000000656")!
        let voiceMemo = VoiceMemo(
            id: voiceMemoID,
            projectID: UUID(),
            title: "Deleted memo",
            duration: 42,
            createdAt: Date(timeIntervalSince1970: 1_000),
            updatedAt: Date(timeIntervalSince1970: 1_000)
        )
        try encodeVoiceMemoSnapshot(
            TickVoiceMemoStorageSnapshot(voiceMemos: [voiceMemo]),
            at: urls.iCloudMetadataFileURL
        )
        let iCloudAudioURL = urls.iCloudAudioDirectoryURL.appendingPathComponent(voiceMemo.fileName)
        try FileManager.default.createDirectory(at: urls.iCloudAudioDirectoryURL, withIntermediateDirectories: true)
        try Data([7, 8, 9]).write(to: iCloudAudioURL)
        let store = TickVoiceMemoStore(
            metadataFileURL: urls.metadataFileURL,
            voiceMemoDirectoryURL: urls.audioDirectoryURL,
            iCloudMetadataFileURL: urls.iCloudMetadataFileURL,
            iCloudVoiceMemoDirectoryURL: urls.iCloudAudioDirectoryURL
        )

        try await store.save(
            [],
            deletedVoiceMemoIDs: [voiceMemoID],
            deletedAt: Date(timeIntervalSince1970: 2_000)
        )
        let loadedVoiceMemos = try await store.load()
        let iCloudSnapshot = try decodeVoiceMemoSnapshot(at: urls.iCloudMetadataFileURL)

        XCTAssertTrue(loadedVoiceMemos.isEmpty)
        XCTAssertTrue(iCloudSnapshot.voiceMemos.isEmpty)
        XCTAssertEqual(iCloudSnapshot.deletedVoiceMemos.first?.id, voiceMemoID)
        XCTAssertEqual(iCloudSnapshot.deletedVoiceMemos.first?.fileName, voiceMemo.fileName)
        XCTAssertFalse(FileManager.default.fileExists(atPath: iCloudAudioURL.path))
    }

    func testProjectAccentAssignmentIsStable() {
        let projectID = UUID(uuidString: "00000000-0000-0000-0000-000000000123")!

        XCTAssertEqual(TickProjectAccent.index(for: projectID), TickProjectAccent.index(for: projectID))
    }

    @MainActor
    func testProjectAccentAssignmentDistributesSampleProjects() {
        let sampleProjectIDs = [
            UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
            UUID(uuidString: "00000000-0000-0000-0000-000000000003")!,
            UUID(uuidString: "00000000-0000-0000-0000-000000000004")!
        ]
        let accentIndexes = Set(sampleProjectIDs.map(TickProjectAccent.index(for:)))

        XCTAssertEqual(accentIndexes.count, sampleProjectIDs.count)
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
        XCTAssertNil(snapshot.activePausedAt)
        XCTAssertEqual(snapshot.activeElapsedDuration, 600)
        XCTAssertEqual(snapshot.todayTotalDuration, 600)
    }

    func testWidgetSnapshotGenerationWithPausedSession() {
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
            pausedAt: Date(timeIntervalSince1970: 160),
            accumulatedPausedDuration: nil,
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
        XCTAssertEqual(snapshot.activePausedAt, Date(timeIntervalSince1970: 160))
        XCTAssertEqual(snapshot.activeElapsedDuration, 60)
        XCTAssertEqual(snapshot.todayTotalDuration, 60)
        XCTAssertTrue(snapshot.isActivePaused)
    }

    func testWidgetSnapshotDecodesLegacySnapshotWithoutPausedFields() throws {
        let id = UUID()
        let json = """
        {
          "activeProjectName" : "Studio",
          "activeSessionID" : "\(id.uuidString)",
          "activeSessionTitle" : "1 Tick",
          "activeStartedAt" : "1970-01-01T00:01:40Z",
          "defaultProjectID" : null,
          "defaultProjectName" : null,
          "hasProjects" : true,
          "lastUpdatedAt" : "1970-01-01T00:01:40Z",
          "todayTotalDuration" : 600
        }
        """
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let snapshot = try decoder.decode(TickWidgetSnapshot.self, from: Data(json.utf8))

        XCTAssertEqual(snapshot.activeSessionID, id)
        XCTAssertNil(snapshot.activePausedAt)
        XCTAssertNil(snapshot.activeElapsedDuration)
        XCTAssertFalse(snapshot.isActivePaused)
    }

    func testAccessoryRectangularNoProjectContent() {
        let content = TickAccessoryWidgetContentBuilder.content(
            from: .empty(lastUpdatedAt: Date(timeIntervalSince1970: 100)),
            at: Date(timeIntervalSince1970: 100)
        )

        XCTAssertEqual(content.state, .noProjects)
        XCTAssertEqual(content.rectangularTitle, "Ticks")
        XCTAssertEqual(content.rectangularDetail, "Create a space")
        XCTAssertEqual(content.circularText, "0")
        XCTAssertEqual(content.inlineText, "Ticks: create a space")
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
        XCTAssertEqual(content.inlineText, "PiSignage: 42m today")
    }

    func testAccessoryRectangularPausedContent() {
        let snapshot = TickWidgetSnapshot(
            hasProjects: true,
            defaultProjectID: nil,
            defaultProjectName: nil,
            activeSessionID: UUID(),
            activeProjectName: "PiSignage",
            activeSessionTitle: "1 Tick",
            activeStartedAt: Date(timeIntervalSince1970: 100),
            activePausedAt: Date(timeIntervalSince1970: 160),
            activeElapsedDuration: 60,
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
        XCTAssertEqual(content.rectangularFootnote, "Paused")
        XCTAssertEqual(content.inlineText, "PiSignage: 42m today")
        XCTAssertEqual(content.accessibilityLabel, "PiSignage paused. 42m today.")
    }

    func testAccessoryActiveContentShowsTodayTotalInsteadOfElapsedTime() {
        let snapshot = TickWidgetSnapshot(
            hasProjects: true,
            defaultProjectID: nil,
            defaultProjectName: nil,
            activeSessionID: UUID(),
            activeProjectName: "PiSignage",
            activeSessionTitle: "UI work",
            activeStartedAt: Date(timeIntervalSince1970: 100),
            todayTotalDuration: 15_180,
            lastUpdatedAt: Date(timeIntervalSince1970: 100)
        )
        let content = TickAccessoryWidgetContentBuilder.content(
            from: snapshot,
            at: Date(timeIntervalSince1970: 640)
        )

        XCTAssertEqual(content.state, .active)
        XCTAssertEqual(content.rectangularDetail, "4h 13m")
        XCTAssertEqual(content.circularText, "4h 13m")
        XCTAssertEqual(content.inlineText, "PiSignage: 4h 13m today")
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

    func testWidgetStoredSessionDurationExcludesPausedTime() {
        let session = TickWidgetStoredSession(
            id: UUID(),
            projectID: UUID(),
            title: "",
            notes: "",
            startedAt: Date(timeIntervalSince1970: 100),
            endedAt: nil,
            manualDuration: nil,
            pausedAt: Date(timeIntervalSince1970: 160),
            accumulatedPausedDuration: 30,
            entrySource: "timer",
            autoTickRuleID: nil,
            createdAt: Date(timeIntervalSince1970: 100)
        )

        XCTAssertEqual(session.duration(at: Date(timeIntervalSince1970: 400)), 30)
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

    func testWidgetSnapshotLoadReconcilesStoppedSessionFromStorage() async throws {
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
        let sessionID = UUID()
        let stoppedSession = TickWidgetStoredSession(
            id: sessionID,
            projectID: project.id,
            title: "",
            notes: "",
            startedAt: Date(timeIntervalSince1970: 100),
            endedAt: Date(timeIntervalSince1970: 300),
            manualDuration: nil,
            entrySource: "timer",
            autoTickRuleID: nil,
            createdAt: Date(timeIntervalSince1970: 100)
        )
        let staleActiveSnapshot = TickWidgetSnapshot(
            hasProjects: true,
            defaultProjectID: project.id,
            defaultProjectName: "Studio",
            activeSessionID: sessionID,
            activeProjectName: "Studio",
            activeSessionTitle: "1 Tick",
            activeStartedAt: Date(timeIntervalSince1970: 100),
            todayTotalDuration: 200,
            lastUpdatedAt: Date(timeIntervalSince1970: 200)
        )
        let store = TickWidgetActionStore(
            dataFileURL: urls.dataFileURL,
            widgetSnapshotFileURL: urls.snapshotFileURL
        )

        try await seedWidgetStore(
            TickWidgetStorageSnapshot(projects: [project], sessions: [stoppedSession]),
            at: urls.dataFileURL
        )
        try store.saveWidgetSnapshot(staleActiveSnapshot)

        let loadedSnapshot = try store.loadWidgetSnapshot(at: Date(timeIntervalSince1970: 400))

        XCTAssertNil(loadedSnapshot.activeSessionID)
        XCTAssertNil(loadedSnapshot.activeStartedAt)
        XCTAssertEqual(loadedSnapshot.todayTotalDuration, 200)
    }

    func testWidgetSnapshotLoadReconcilesPausedSessionFromStorage() async throws {
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
        let sessionID = UUID()
        let pausedSession = TickWidgetStoredSession(
            id: sessionID,
            projectID: project.id,
            title: "",
            notes: "",
            startedAt: Date(timeIntervalSince1970: 100),
            endedAt: nil,
            manualDuration: nil,
            pausedAt: Date(timeIntervalSince1970: 160),
            entrySource: "timer",
            autoTickRuleID: nil,
            createdAt: Date(timeIntervalSince1970: 100)
        )
        let staleRunningSnapshot = TickWidgetSnapshot(
            hasProjects: true,
            defaultProjectID: project.id,
            defaultProjectName: "Studio",
            activeSessionID: sessionID,
            activeProjectName: "Studio",
            activeSessionTitle: "1 Tick",
            activeStartedAt: Date(timeIntervalSince1970: 100),
            activePausedAt: nil,
            activeElapsedDuration: 300,
            todayTotalDuration: 300,
            lastUpdatedAt: Date(timeIntervalSince1970: 400)
        )
        let store = TickWidgetActionStore(
            dataFileURL: urls.dataFileURL,
            widgetSnapshotFileURL: urls.snapshotFileURL
        )

        try await seedWidgetStore(
            TickWidgetStorageSnapshot(projects: [project], sessions: [pausedSession]),
            at: urls.dataFileURL
        )
        try store.saveWidgetSnapshot(staleRunningSnapshot)

        let loadedSnapshot = try store.loadWidgetSnapshot(at: Date(timeIntervalSince1970: 500))

        XCTAssertEqual(loadedSnapshot.activeSessionID, sessionID)
        XCTAssertEqual(loadedSnapshot.activePausedAt, Date(timeIntervalSince1970: 160))
        XCTAssertEqual(loadedSnapshot.activeElapsedDuration, 60)
        XCTAssertEqual(loadedSnapshot.todayTotalDuration, 60)
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
    func testViewModelPauseFreezesDurationUntilResume() async {
        let fileURL = temporaryStoreURL()
        defer {
            try? FileManager.default.removeItem(at: fileURL.deletingLastPathComponent())
        }

        let viewModel = TickViewModel(store: TickDataStore(fileURL: fileURL))
        await viewModel.addProject(name: "Tick", createdAt: Date(timeIntervalSince1970: 0))

        await viewModel.startTick(at: Date(timeIntervalSince1970: 100))
        let didPause = await viewModel.pauseTick(at: Date(timeIntervalSince1970: 160))

        XCTAssertTrue(didPause)
        XCTAssertTrue(viewModel.activeSession?.isPaused == true)
        XCTAssertEqual(viewModel.activeSession?.duration(at: Date(timeIntervalSince1970: 220)), 60)

        let didResume = await viewModel.resumeTick(at: Date(timeIntervalSince1970: 220))

        XCTAssertTrue(didResume)
        XCTAssertFalse(viewModel.activeSession?.isPaused == true)
        XCTAssertEqual(viewModel.activeSession?.duration(at: Date(timeIntervalSince1970: 250)), 90)
    }

    @MainActor
    func testStoppingPausedTickDoesNotIncludePausedTime() async {
        let fileURL = temporaryStoreURL()
        defer {
            try? FileManager.default.removeItem(at: fileURL.deletingLastPathComponent())
        }

        let viewModel = TickViewModel(store: TickDataStore(fileURL: fileURL))
        await viewModel.addProject(name: "Tick", createdAt: Date(timeIntervalSince1970: 0))

        await viewModel.startTick(at: Date(timeIntervalSince1970: 100))
        await viewModel.pauseTick(at: Date(timeIntervalSince1970: 160))
        let didStop = await viewModel.stopTick(at: Date(timeIntervalSince1970: 400))

        XCTAssertTrue(didStop)
        XCTAssertNil(viewModel.activeSession)
        XCTAssertEqual(viewModel.sessions.first?.endedAt, Date(timeIntervalSince1970: 160))
        XCTAssertEqual(viewModel.sessions.first?.duration(at: Date(timeIntervalSince1970: 400)), 60)
    }

    @MainActor
    func testArchiveProjectRemovesProjectFromActiveProjects() async {
        let fileURL = temporaryStoreURL()
        defer { try? FileManager.default.removeItem(at: fileURL.deletingLastPathComponent()) }

        let viewModel = TickViewModel(store: TickDataStore(fileURL: fileURL))
        await viewModel.addProject(name: "Alpha", createdAt: Date(timeIntervalSince1970: 0))
        guard let projectID = viewModel.activeProjects.first?.id else {
            XCTFail("Expected a project to archive.")
            return
        }

        let didArchive = await viewModel.archiveProject(id: projectID)

        XCTAssertTrue(didArchive)
        XCTAssertTrue(viewModel.projects.contains(where: { $0.id == projectID && $0.isArchived }))
        XCTAssertFalse(viewModel.activeProjects.contains(where: { $0.id == projectID }))
    }

    @MainActor
    func testRestoreProjectReturnsProjectToActiveProjects() async {
        let fileURL = temporaryStoreURL()
        defer { try? FileManager.default.removeItem(at: fileURL.deletingLastPathComponent()) }

        let viewModel = TickViewModel(store: TickDataStore(fileURL: fileURL))
        await viewModel.addProject(name: "Alpha", createdAt: Date(timeIntervalSince1970: 0))
        guard let projectID = viewModel.activeProjects.first?.id else {
            XCTFail("Expected a project to restore.")
            return
        }
        _ = await viewModel.archiveProject(id: projectID)

        let didRestore = await viewModel.restoreProject(id: projectID)

        XCTAssertTrue(didRestore)
        XCTAssertTrue(viewModel.projects.contains(where: { $0.id == projectID && !$0.isArchived }))
        XCTAssertTrue(viewModel.activeProjects.contains(where: { $0.id == projectID }))
    }

    @MainActor
    func testMovingActiveProjectsPersistsDisplayOrder() async throws {
        let fileURL = temporaryStoreURL()
        defer { try? FileManager.default.removeItem(at: fileURL.deletingLastPathComponent()) }

        let viewModel = TickViewModel(store: TickDataStore(fileURL: fileURL))
        await viewModel.addProject(name: "Alpha", createdAt: Date(timeIntervalSince1970: 0))
        await viewModel.addProject(name: "Beta", createdAt: Date(timeIntervalSince1970: 1))
        await viewModel.addProject(name: "Gamma", createdAt: Date(timeIntervalSince1970: 2))
        let projectIDs = viewModel.activeProjects.map(\.id)

        let didMove = await viewModel.moveActiveProjects(from: IndexSet(integer: 1), to: 0)

        XCTAssertTrue(didMove)
        XCTAssertEqual(viewModel.activeProjects.map(\.id), [projectIDs[1], projectIDs[0], projectIDs[2]])

        let reloadedViewModel = TickViewModel(store: TickDataStore(fileURL: fileURL))
        await reloadedViewModel.reload()

        XCTAssertEqual(reloadedViewModel.activeProjects.map(\.id), [projectIDs[1], projectIDs[0], projectIDs[2]])
    }

    @MainActor
    func testAddingProjectSelectsNewProject() async {
        let fileURL = temporaryStoreURL()
        defer { try? FileManager.default.removeItem(at: fileURL.deletingLastPathComponent()) }

        let viewModel = TickViewModel(store: TickDataStore(fileURL: fileURL))
        await viewModel.addProject(name: "First", createdAt: Date(timeIntervalSince1970: 0))
        let firstProjectID = viewModel.selectedProjectID

        await viewModel.addProject(name: "Second", createdAt: Date(timeIntervalSince1970: 1))

        XCTAssertNotNil(firstProjectID)
        XCTAssertEqual(viewModel.selectedProjectID, viewModel.activeProjects.last?.id)
        XCTAssertNotEqual(viewModel.selectedProjectID, firstProjectID)
    }

    @MainActor
    func testArchivingSelectedProjectUpdatesSelectionToAnotherActiveProject() async {
        let fileURL = temporaryStoreURL()
        defer { try? FileManager.default.removeItem(at: fileURL.deletingLastPathComponent()) }

        let viewModel = TickViewModel(store: TickDataStore(fileURL: fileURL))
        await viewModel.addProject(name: "First", createdAt: Date(timeIntervalSince1970: 0))
        await viewModel.addProject(name: "Second", createdAt: Date(timeIntervalSince1970: 1))
        let firstProjectID = viewModel.activeProjects[0].id
        let secondProjectID = viewModel.activeProjects[1].id
        viewModel.selectedProjectID = firstProjectID

        let didArchive = await viewModel.archiveProject(id: firstProjectID)

        XCTAssertTrue(didArchive)
        XCTAssertEqual(viewModel.selectedProjectID, secondProjectID)
    }

    @MainActor
    func testArchivingProjectWithActiveSessionFails() async {
        let fileURL = temporaryStoreURL()
        defer { try? FileManager.default.removeItem(at: fileURL.deletingLastPathComponent()) }

        let viewModel = TickViewModel(store: TickDataStore(fileURL: fileURL))
        await viewModel.addProject(name: "Studio", createdAt: Date(timeIntervalSince1970: 0))
        guard let projectID = viewModel.activeProjects.first?.id else {
            XCTFail("Expected a project for active session test.")
            return
        }
        _ = await viewModel.startTick(at: Date(timeIntervalSince1970: 100))

        let didArchive = await viewModel.archiveProject(id: projectID)

        XCTAssertFalse(didArchive)
        XCTAssertEqual(viewModel.errorMessage, "Stop the active Tick before archiving this space.")
        XCTAssertTrue(viewModel.activeProjects.contains(where: { $0.id == projectID }))
    }

    @MainActor
    func testArchivingProjectDoesNotDeleteExistingSessions() async {
        let fileURL = temporaryStoreURL()
        defer { try? FileManager.default.removeItem(at: fileURL.deletingLastPathComponent()) }

        let viewModel = TickViewModel(store: TickDataStore(fileURL: fileURL))
        await viewModel.addProject(name: "Studio", createdAt: Date(timeIntervalSince1970: 0))
        guard let projectID = viewModel.activeProjects.first?.id else {
            XCTFail("Expected a project to archive.")
            return
        }
        await viewModel.addManualSession(
            projectID: projectID,
            title: "Manual",
            notes: "",
            date: Date(timeIntervalSince1970: 100),
            duration: 900
        )

        let didArchive = await viewModel.archiveProject(id: projectID)

        XCTAssertTrue(didArchive)
        XCTAssertEqual(viewModel.sessions(for: projectID).count, 1)
    }

    @MainActor
    func testArchivingProjectDoesNotDeleteAutoTickRules() async {
        let fileURL = temporaryStoreURL()
        defer { try? FileManager.default.removeItem(at: fileURL.deletingLastPathComponent()) }

        let viewModel = TickViewModel(store: TickDataStore(fileURL: fileURL))
        await viewModel.addProject(name: "Studio", createdAt: Date(timeIntervalSince1970: 0))
        guard let projectID = viewModel.activeProjects.first?.id else {
            XCTFail("Expected a project to archive.")
            return
        }
        await viewModel.addAutoTickRule(
            projectID: projectID,
            name: "Office",
            latitude: 37.3318,
            longitude: -122.0312,
            radiusMeters: 100,
            startsOnArrival: true,
            stopsOnDeparture: true,
            isEnabled: true
        )

        let didArchive = await viewModel.archiveProject(id: projectID)

        XCTAssertTrue(didArchive)
        XCTAssertEqual(viewModel.autoTickRules.count, 1)
        XCTAssertEqual(viewModel.autoTickRules.first?.projectID, projectID)
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
    func testAutoTickArrivalResumesPausedAssociatedAutoSession() async {
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
            isEnabled: true
        )

        let rule = viewModel.autoTickRules[0]
        await viewModel.handleAutoTickEvent(
            ruleID: rule.id,
            event: .arrival,
            at: Date(timeIntervalSince1970: 100)
        )
        await viewModel.pauseTick(at: Date(timeIntervalSince1970: 160))

        let didResume = await viewModel.handleAutoTickEvent(
            ruleID: rule.id,
            event: .arrival,
            at: Date(timeIntervalSince1970: 220)
        )

        XCTAssertTrue(didResume)
        XCTAssertEqual(viewModel.sessions.filter(\.isActive).count, 1)
        XCTAssertFalse(viewModel.activeSession?.isPaused == true)
        XCTAssertEqual(viewModel.activeSession?.entrySource, .autoLocation)
        XCTAssertEqual(viewModel.activeSession?.autoTickRuleID, rule.id)
        XCTAssertEqual(viewModel.activeSession?.accumulatedPausedDuration, 60)
        XCTAssertEqual(viewModel.activeSession?.duration(at: Date(timeIntervalSince1970: 250)), 90)
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

    private func temporaryVoiceMemoStoreURLs() -> (
        directoryURL: URL,
        metadataFileURL: URL,
        audioDirectoryURL: URL,
        iCloudMetadataFileURL: URL,
        iCloudAudioDirectoryURL: URL
    ) {
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let iCloudDirectoryURL = directoryURL.appendingPathComponent("iCloud", isDirectory: true)

        return (
            directoryURL,
            directoryURL.appendingPathComponent("tick-voice-memos.json"),
            directoryURL.appendingPathComponent("VoiceMemos", isDirectory: true),
            iCloudDirectoryURL.appendingPathComponent("tick-voice-memos.json"),
            iCloudDirectoryURL.appendingPathComponent("VoiceMemos", isDirectory: true)
        )
    }

    private func encodeVoiceMemoSnapshot(_ snapshot: TickVoiceMemoStorageSnapshot, at fileURL: URL) throws {
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

    private func decodeVoiceMemoSnapshot(at fileURL: URL) throws -> TickVoiceMemoStorageSnapshot {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let data = try Data(contentsOf: fileURL)
        return try decoder.decode(TickVoiceMemoStorageSnapshot.self, from: data)
    }

    func testUntitledSessionTitlesNumbersOnlyUntitledSessionsInInputOrder() {
        let projectID = UUID()
        let titled = TimeSession(
            projectID: projectID,
            title: "Planning",
            notes: "",
            startedAt: Date(timeIntervalSince1970: 1),
            endedAt: nil,
            manualDuration: 300,
            entrySource: .manual
        )
        let untitledA = TimeSession(
            projectID: projectID,
            title: " ",
            notes: "",
            startedAt: Date(timeIntervalSince1970: 2),
            endedAt: nil,
            manualDuration: 300,
            entrySource: .manual
        )
        let untitledB = TimeSession(
            projectID: projectID,
            title: "",
            notes: "",
            startedAt: Date(timeIntervalSince1970: 3),
            endedAt: nil,
            manualDuration: 300,
            entrySource: .manual
        )

        let titles = SessionFallbackTitleProvider.untitledSessionTitles(for: [titled, untitledA, untitledB])

        XCTAssertEqual(titles[untitledA.id], "1 Tick")
        XCTAssertEqual(titles[untitledB.id], "2 Tick")
        XCTAssertNil(titles[titled.id])
    }

    func testFallbackTitleReturnsTickForTitledSession() {
        let projectID = UUID()
        let titled = TimeSession(
            projectID: projectID,
            title: "Named",
            notes: "",
            startedAt: Date(timeIntervalSince1970: 10),
            endedAt: nil,
            manualDuration: 600,
            entrySource: .manual
        )

        let fallback = SessionFallbackTitleProvider.fallbackTitle(for: titled, in: [titled])

        XCTAssertEqual(fallback, "Tick")
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

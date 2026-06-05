import Foundation
import Observation
import WidgetKit

@MainActor
@Observable
final class TickViewModel {
    private let store: TickDataStore
    private let voiceMemoStore: TickVoiceMemoStore
    private let locationService: AutoTickLocationService
    private let iCloudSyncStore: TickICloudSyncStore?
    private let voiceMemoICloudSyncStore: TickVoiceMemoICloudSyncStore?
    private let voiceMemoAudioController: TickVoiceMemoAudioController
    @ObservationIgnored private var iCloudSyncObserver: NSObjectProtocol?
    @ObservationIgnored private var recordingVoiceMemoID: VoiceMemo.ID?
    @ObservationIgnored private var recordingVoiceMemoFileName: String?
    @ObservationIgnored private var recordingVoiceMemoStartedAt: Date?

    private(set) var projects: [TickProject] = []
    private(set) var sessions: [TimeSession] = []
    private(set) var autoTickRules: [AutoTickRule] = []
    private(set) var voiceMemos: [VoiceMemo] = []
    private(set) var autoTickLocationAuthorizationStatus: AutoTickLocationAuthorizationStatus
    private(set) var latestAutoTickCoordinate: AutoTickCoordinate?
    private(set) var autoTickLocationMessage: String
    private(set) var autoTickLocationErrorMessage: String?
    private(set) var recordingVoiceMemoProjectID: TickProject.ID?
    private(set) var playingVoiceMemoID: VoiceMemo.ID?
    var selectedProjectID: TickProject.ID?
    var errorMessage: String?
    private(set) var hasLoaded = false

    init() {
        self.store = TickDataStore()
        self.voiceMemoStore = TickVoiceMemoStore()
        self.locationService = AutoTickLocationService()
        self.iCloudSyncStore = TickICloudSyncStore()
        self.voiceMemoICloudSyncStore = TickVoiceMemoICloudSyncStore()
        self.voiceMemoAudioController = TickVoiceMemoAudioController()

        let locationState = locationService.currentState
        self.autoTickLocationAuthorizationStatus = locationState.authorizationStatus
        self.latestAutoTickCoordinate = locationState.latestCoordinate
        self.autoTickLocationMessage = locationState.statusMessage
        self.autoTickLocationErrorMessage = locationState.errorMessage

        configureLocationServiceCallbacks()
        configureICloudSyncCallbacks()
        configureVoiceMemoCallbacks()
    }

    init(store: TickDataStore) {
        self.store = store
        self.voiceMemoStore = TickVoiceMemoStore()
        self.locationService = AutoTickLocationService()
        self.iCloudSyncStore = nil
        self.voiceMemoICloudSyncStore = nil
        self.voiceMemoAudioController = TickVoiceMemoAudioController()

        let locationState = locationService.currentState
        self.autoTickLocationAuthorizationStatus = locationState.authorizationStatus
        self.latestAutoTickCoordinate = locationState.latestCoordinate
        self.autoTickLocationMessage = locationState.statusMessage
        self.autoTickLocationErrorMessage = locationState.errorMessage

        configureLocationServiceCallbacks()
        configureVoiceMemoCallbacks()
    }

    init(store: TickDataStore, voiceMemoStore: TickVoiceMemoStore) {
        self.store = store
        self.voiceMemoStore = voiceMemoStore
        self.locationService = AutoTickLocationService()
        self.iCloudSyncStore = nil
        self.voiceMemoICloudSyncStore = nil
        self.voiceMemoAudioController = TickVoiceMemoAudioController()

        let locationState = locationService.currentState
        self.autoTickLocationAuthorizationStatus = locationState.authorizationStatus
        self.latestAutoTickCoordinate = locationState.latestCoordinate
        self.autoTickLocationMessage = locationState.statusMessage
        self.autoTickLocationErrorMessage = locationState.errorMessage

        configureLocationServiceCallbacks()
        configureVoiceMemoCallbacks()
    }

    init(
        store: TickDataStore,
        locationService: AutoTickLocationService,
        iCloudSyncStore: TickICloudSyncStore? = nil,
        voiceMemoICloudSyncStore: TickVoiceMemoICloudSyncStore? = nil,
        voiceMemoStore: TickVoiceMemoStore = TickVoiceMemoStore(),
        voiceMemoAudioController: TickVoiceMemoAudioController? = nil
    ) {
        self.store = store
        self.voiceMemoStore = voiceMemoStore
        self.locationService = locationService
        self.iCloudSyncStore = iCloudSyncStore
        self.voiceMemoICloudSyncStore = voiceMemoICloudSyncStore
        self.voiceMemoAudioController = voiceMemoAudioController ?? TickVoiceMemoAudioController()

        let locationState = locationService.currentState
        self.autoTickLocationAuthorizationStatus = locationState.authorizationStatus
        self.latestAutoTickCoordinate = locationState.latestCoordinate
        self.autoTickLocationMessage = locationState.statusMessage
        self.autoTickLocationErrorMessage = locationState.errorMessage

        configureLocationServiceCallbacks()
        configureICloudSyncCallbacks()
        configureVoiceMemoCallbacks()
    }

    deinit {
        if let iCloudSyncObserver {
            NotificationCenter.default.removeObserver(iCloudSyncObserver)
        }
    }

    private func configureLocationServiceCallbacks() {
        locationService.stateDidChange = { [weak self] state in
            self?.apply(locationState: state)
        }
        locationService.regionEventHandler = { [weak self] ruleID, event in
            Task { @MainActor in
                await self?.handleAutoTickEvent(ruleID: ruleID, event: event)
            }
        }
    }

    private func configureICloudSyncCallbacks() {
        guard iCloudSyncStore != nil || voiceMemoICloudSyncStore != nil else {
            return
        }

        iCloudSyncObserver = NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.applyRemoteICloudSnapshotIfNeeded()
                await self?.reloadVoiceMemos()
            }
        }
    }

    private func configureVoiceMemoCallbacks() {
        voiceMemoAudioController.playbackDidFinish = { [weak self] voiceMemoID in
            guard self?.playingVoiceMemoID == voiceMemoID else {
                return
            }

            self?.playingVoiceMemoID = nil
        }
    }

    var activeProjects: [TickProject] {
        TickProject.sortedByDisplayOrder(projects.filter { !$0.isArchived })
    }

    var activeSession: TimeSession? {
        sessions.first { $0.isActive }
    }

    func loadIfNeeded() async {
        guard !hasLoaded else {
            return
        }

        await reload()
    }

    func reload() async {
        do {
            let snapshot = try await store.load()
            let localModifiedAt = try? await store.modificationDate()
            let resolvedSnapshot = await resolveICloudSnapshot(
                localSnapshot: snapshot,
                localModifiedAt: localModifiedAt
            )
            apply(storageSnapshot: resolvedSnapshot)
            await reloadVoiceMemos()
            hasLoaded = true
            refreshAutoTickMonitoring()
            await refreshWidgetSnapshot()
        } catch {
            errorMessage = "Tick could not load saved time. \(error.localizedDescription)"
            hasLoaded = true
        }
    }

    @discardableResult
    func addProject(name: String, createdAt: Date = .now) async -> Bool {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedName.isEmpty else {
            errorMessage = "Space name cannot be empty."
            return false
        }

        let project = TickProject(name: trimmedName, createdAt: createdAt)
        projects.append(project)
        projects = TickProject.sortedByDisplayOrder(projects)

        if selectedProjectID == nil {
            selectedProjectID = project.id
        }

        await persist()
        return true
    }

    @discardableResult
    func deleteProject(id: TickProject.ID) async -> Bool {
        guard let projectIndex = projects.firstIndex(where: { $0.id == id }) else {
            errorMessage = "Tick could not find that space."
            return false
        }

        guard activeSession?.projectID != id else {
            errorMessage = "Stop the active Tick before deleting this space."
            return false
        }

        projects.remove(at: projectIndex)
        sessions.removeAll { $0.projectID == id }
        autoTickRules.removeAll { $0.projectID == id }
        let deletedVoiceMemos = voiceMemos.filter { $0.projectID == id }
        voiceMemos.removeAll { $0.projectID == id }

        if selectedProjectID == id {
            selectedProjectID = activeProjects.first?.id
        }

        await persist()
        await persistVoiceMemos(deletedVoiceMemoIDs: deletedVoiceMemos.map(\.id))
        await deleteVoiceMemoFiles(deletedVoiceMemos)
        return true
    }

    @discardableResult
    func moveActiveProjects(from source: IndexSet, to destination: Int) async -> Bool {
        await moveProjects(from: source, to: destination, isIncluded: { !$0.isArchived })
    }

    @discardableResult
    func moveArchivedProjects(from source: IndexSet, to destination: Int) async -> Bool {
        await moveProjects(from: source, to: destination, isIncluded: \.isArchived)
    }

    @discardableResult
    func archiveProject(id: TickProject.ID) async -> Bool {
        guard let projectIndex = projects.firstIndex(where: { $0.id == id }) else {
            errorMessage = "Tick could not find that space."
            return false
        }

        guard activeSession?.projectID != id else {
            errorMessage = "Stop the active Tick before archiving this space."
            return false
        }

        projects[projectIndex].isArchived = true

        if selectedProjectID == id {
            selectedProjectID = activeProjects.first?.id
        }

        await persist()
        return true
    }

    @discardableResult
    func restoreProject(id: TickProject.ID) async -> Bool {
        guard let projectIndex = projects.firstIndex(where: { $0.id == id }) else {
            errorMessage = "Tick could not find that space."
            return false
        }

        projects[projectIndex].isArchived = false

        if selectedProjectID == nil {
            selectedProjectID = project(for: id)?.id ?? activeProjects.first?.id
        }

        await persist()
        return true
    }

    @discardableResult
    func startTick(at date: Date = .now) async -> Bool {
        guard activeSession == nil else {
            errorMessage = "Stop the current Tick before starting another one."
            return false
        }

        guard let selectedProjectID else {
            errorMessage = "Choose or create a space before starting Tick."
            return false
        }

        guard activeProjects.contains(where: { $0.id == selectedProjectID }) else {
            self.selectedProjectID = activeProjects.first?.id
            errorMessage = "Choose or create a space before starting Tick."
            return false
        }

        let session = TimeSession(
            projectID: selectedProjectID,
            title: "",
            notes: "",
            startedAt: date,
            endedAt: nil,
            manualDuration: nil,
            entrySource: .timer,
            createdAt: date
        )
        sessions.insert(session, at: 0)
        await persist()
        return true
    }

    @discardableResult
    func stopTick(at date: Date = .now) async -> Bool {
        guard let activeSession, let activeIndex = sessions.firstIndex(where: { $0.id == activeSession.id }) else {
            errorMessage = "There is no active Tick to stop."
            return false
        }

        let startedAt = activeSession.startedAt ?? date
        let pauseDate = activeSession.pausedAt
        let endedAt = pauseDate ?? date
        sessions[activeIndex].endedAt = endedAt < startedAt ? startedAt : endedAt
        sessions[activeIndex].pausedAt = nil
        sessions.sort { $0.referenceDate > $1.referenceDate }
        await persist()
        return true
    }

    @discardableResult
    func pauseTick(at date: Date = .now) async -> Bool {
        guard let activeSession, let activeIndex = sessions.firstIndex(where: { $0.id == activeSession.id }) else {
            errorMessage = "There is no active Tick to pause."
            return false
        }

        guard !activeSession.isPaused else {
            return true
        }

        let startedAt = activeSession.startedAt ?? date
        sessions[activeIndex].pausedAt = date < startedAt ? startedAt : date
        await persist()
        return true
    }

    @discardableResult
    func resumeTick(at date: Date = .now) async -> Bool {
        guard let activeSession, let activeIndex = sessions.firstIndex(where: { $0.id == activeSession.id }) else {
            errorMessage = "There is no paused Tick to resume."
            return false
        }

        guard let pausedAt = activeSession.pausedAt else {
            return true
        }

        let pauseDuration = max(0, date.timeIntervalSince(pausedAt))
        sessions[activeIndex].accumulatedPausedDuration = (activeSession.accumulatedPausedDuration ?? 0) + pauseDuration
        sessions[activeIndex].pausedAt = nil
        await persist()
        return true
    }

    @discardableResult
    func addManualSession(
        projectID: TickProject.ID?,
        title: String,
        notes: String,
        date: Date,
        duration: TimeInterval
    ) async -> Bool {
        guard let projectID else {
            errorMessage = "Choose a space for this manual time."
            return false
        }

        guard duration > 0 else {
            errorMessage = "Manual time must be longer than zero minutes."
            return false
        }

        let session = TimeSession(
            projectID: projectID,
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
            startedAt: date,
            endedAt: nil,
            manualDuration: duration,
            entrySource: .manual,
            createdAt: .now
        )
        sessions.insert(session, at: 0)
        sessions.sort { $0.referenceDate > $1.referenceDate }
        await persist()
        return true
    }

    @discardableResult
    func addAutoTickRule(
        projectID: TickProject.ID?,
        name: String,
        latitude: Double?,
        longitude: Double?,
        radiusMeters: Double,
        startsOnArrival: Bool,
        stopsOnDeparture: Bool,
        isEnabled: Bool,
        createdAt: Date = .now
    ) async -> Bool {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let projectID, projects.contains(where: { $0.id == projectID }) else {
            errorMessage = "Choose a space for this Auto Tick."
            return false
        }

        guard !trimmedName.isEmpty else {
            errorMessage = "Name this Auto Tick location."
            return false
        }

        guard let latitude, let longitude else {
            errorMessage = "Use current location before saving this Auto Tick."
            return false
        }

        guard radiusMeters > 0 else {
            errorMessage = "Auto Tick radius must be greater than zero meters."
            return false
        }

        guard startsOnArrival || stopsOnDeparture else {
            errorMessage = "Choose arrival, departure, or both for this Auto Tick."
            return false
        }

        let rule = AutoTickRule(
            projectID: projectID,
            name: trimmedName,
            latitude: latitude,
            longitude: longitude,
            radiusMeters: radiusMeters,
            startsOnArrival: startsOnArrival,
            stopsOnDeparture: stopsOnDeparture,
            isEnabled: isEnabled,
            createdAt: createdAt
        )
        autoTickRules.append(rule)
        autoTickRules.sort { $0.createdAt < $1.createdAt }
        await persist()
        return true
    }

    @discardableResult
    func setAutoTickRule(_ ruleID: AutoTickRule.ID, isEnabled: Bool) async -> Bool {
        guard let ruleIndex = autoTickRules.firstIndex(where: { $0.id == ruleID }) else {
            errorMessage = "Tick could not find that Auto Tick rule."
            return false
        }

        autoTickRules[ruleIndex].isEnabled = isEnabled
        await persist()
        return true
    }

    @discardableResult
    func updateAutoTickRule(
        id: AutoTickRule.ID,
        projectID: TickProject.ID?,
        name: String,
        radiusMeters: Double,
        startsOnArrival: Bool,
        stopsOnDeparture: Bool,
        isEnabled: Bool
    ) async -> Bool {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let projectID, projects.contains(where: { $0.id == projectID }) else {
            errorMessage = "Choose a space for this Auto Tick."
            return false
        }

        guard !trimmedName.isEmpty else {
            errorMessage = "Name this Auto Tick location."
            return false
        }

        guard radiusMeters > 0 else {
            errorMessage = "Auto Tick radius must be greater than zero meters."
            return false
        }

        guard startsOnArrival || stopsOnDeparture else {
            errorMessage = "Choose arrival, departure, or both for this Auto Tick."
            return false
        }

        guard let ruleIndex = autoTickRules.firstIndex(where: { $0.id == id }) else {
            errorMessage = "Tick could not find that Auto Tick rule."
            return false
        }

        autoTickRules[ruleIndex].projectID = projectID
        autoTickRules[ruleIndex].name = trimmedName
        autoTickRules[ruleIndex].radiusMeters = radiusMeters
        autoTickRules[ruleIndex].startsOnArrival = startsOnArrival
        autoTickRules[ruleIndex].stopsOnDeparture = stopsOnDeparture
        autoTickRules[ruleIndex].isEnabled = isEnabled
        autoTickRules.sort { $0.createdAt < $1.createdAt }
        await persist()
        return true
    }

    @discardableResult
    func deleteAutoTickRule(id: AutoTickRule.ID) async -> Bool {
        guard let ruleIndex = autoTickRules.firstIndex(where: { $0.id == id }) else {
            errorMessage = "Tick could not find that Auto Tick rule."
            return false
        }

        autoTickRules.remove(at: ruleIndex)
        await persist()
        return true
    }

    func autoTickRule(for id: AutoTickRule.ID) -> AutoTickRule? {
        autoTickRules.first { $0.id == id }
    }

    func requestAutoTickLocationPermission() {
        locationService.requestWhenInUseAuthorization()
    }

    func requestAutoTickBackgroundLocationPermission() {
        locationService.requestAlwaysAuthorization()
    }

    func requestCurrentAutoTickLocation() {
        locationService.requestCurrentLocation()
    }

    @discardableResult
    func handleAutoTickEvent(
        ruleID: AutoTickRule.ID,
        event: AutoTickRegionEvent,
        at date: Date = .now
    ) async -> Bool {
        guard let rule = autoTickRule(for: ruleID), rule.isEnabled else {
            return false
        }

        switch event {
        case .arrival:
            return await startAutoTickIfNeeded(for: rule, at: date)
        case .departure:
            return await stopAutoTickIfNeeded(for: rule, at: date)
        }
    }

    func project(for id: TickProject.ID) -> TickProject? {
        projects.first { $0.id == id }
    }

    private func moveProjects(
        from source: IndexSet,
        to destination: Int,
        isIncluded: (TickProject) -> Bool
    ) async -> Bool {
        let orderedProjects = TickProject.sortedByDisplayOrder(projects)
        let movableProjects = orderedProjects.filter(isIncluded)

        guard source.allSatisfy({ movableProjects.indices.contains($0) }),
              destination >= 0,
              destination <= movableProjects.count else {
            errorMessage = "Tick could not reorder those spaces."
            return false
        }

        guard !source.isEmpty else {
            return true
        }

        let reorderedMovableProjects = Self.reorderedProjects(
            movableProjects,
            moving: source,
            to: destination
        )
        var replacementIndex = 0
        let reorderedProjects = orderedProjects.map { project in
            guard isIncluded(project) else {
                return project
            }

            defer { replacementIndex += 1 }
            return reorderedMovableProjects[replacementIndex]
        }

        for (sortOrder, project) in reorderedProjects.enumerated() {
            guard let projectIndex = projects.firstIndex(where: { $0.id == project.id }) else {
                continue
            }

            projects[projectIndex].sortOrder = Double(sortOrder)
        }

        projects = TickProject.sortedByDisplayOrder(projects)
        await persist()
        return true
    }

    private static func reorderedProjects(
        _ projects: [TickProject],
        moving source: IndexSet,
        to destination: Int
    ) -> [TickProject] {
        var reorderedProjects = projects
        let movedProjects = source.sorted().map { reorderedProjects[$0] }

        for index in source.sorted(by: >) {
            reorderedProjects.remove(at: index)
        }

        let removedBeforeDestination = source.filter { $0 < destination }.count
        let insertionIndex = destination - removedBeforeDestination
        reorderedProjects.insert(contentsOf: movedProjects, at: insertionIndex)
        return reorderedProjects
    }

    func session(for id: TimeSession.ID) -> TimeSession? {
        sessions.first { $0.id == id }
    }

    func sessions(for projectID: TickProject.ID) -> [TimeSession] {
        sessions
            .filter { $0.projectID == projectID }
            .sorted { $0.referenceDate > $1.referenceDate }
    }

    func voiceMemos(for projectID: TickProject.ID) -> [VoiceMemo] {
        voiceMemos
            .filter { $0.projectID == projectID }
            .sorted { $0.createdAt > $1.createdAt }
    }

    func isRecordingVoiceMemo(for projectID: TickProject.ID) -> Bool {
        recordingVoiceMemoProjectID == projectID
    }

    @discardableResult
    func startRecordingVoiceMemo(for projectID: TickProject.ID, at date: Date = .now) async -> Bool {
        guard let project = project(for: projectID) else {
            errorMessage = "Tick could not find that space."
            return false
        }

        guard !project.isArchived else {
            errorMessage = "Restore this space before recording a voice memo."
            return false
        }

        guard recordingVoiceMemoProjectID == nil else {
            errorMessage = "Stop the current voice memo before starting another one."
            return false
        }

        let voiceMemoID = VoiceMemo.ID()
        let fileName = "\(voiceMemoID.uuidString).m4a"

        do {
            let fileURL = try await voiceMemoStore.preparedFileURL(for: fileName)
            try await voiceMemoAudioController.startRecording(to: fileURL)

            recordingVoiceMemoID = voiceMemoID
            recordingVoiceMemoFileName = fileName
            recordingVoiceMemoStartedAt = date
            recordingVoiceMemoProjectID = projectID
            playingVoiceMemoID = nil
            errorMessage = nil
            return true
        } catch {
            errorMessage = "Tick could not start that voice memo. \(error.localizedDescription)"
            return false
        }
    }

    @discardableResult
    func stopRecordingVoiceMemo(title: String = "Voice memo") async -> Bool {
        guard let recordingVoiceMemoID,
              let recordingVoiceMemoFileName,
              let recordingVoiceMemoProjectID else {
            errorMessage = "There is no active voice memo to stop."
            return false
        }

        do {
            let duration = try voiceMemoAudioController.stopRecording()
            let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
            let voiceMemo = VoiceMemo(
                id: recordingVoiceMemoID,
                projectID: recordingVoiceMemoProjectID,
                title: trimmedTitle.isEmpty ? "Voice memo" : trimmedTitle,
                fileName: recordingVoiceMemoFileName,
                duration: duration,
                createdAt: recordingVoiceMemoStartedAt ?? .now,
                updatedAt: .now
            )

            clearVoiceMemoRecordingState()
            voiceMemos.insert(voiceMemo, at: 0)
            voiceMemos.sort { $0.createdAt > $1.createdAt }
            await persistVoiceMemos(audioFileNamesToSync: [voiceMemo.fileName])
            return true
        } catch {
            errorMessage = "Tick could not stop that voice memo. \(error.localizedDescription)"
            return false
        }
    }

    @discardableResult
    func playVoiceMemo(id: VoiceMemo.ID) async -> Bool {
        guard recordingVoiceMemoProjectID == nil else {
            errorMessage = "Stop the active recording before playing a voice memo."
            return false
        }

        guard let voiceMemo = voiceMemos.first(where: { $0.id == id }) else {
            errorMessage = "Tick could not find that voice memo."
            return false
        }

        do {
            let fileURL = await voiceMemoStore.fileURL(for: voiceMemo.fileName)
            try voiceMemoAudioController.playVoiceMemo(id: id, fileURL: fileURL)
            playingVoiceMemoID = playingVoiceMemoID == id ? nil : id
            errorMessage = nil
            return true
        } catch {
            playingVoiceMemoID = nil
            errorMessage = "Tick could not play that voice memo. \(error.localizedDescription)"
            return false
        }
    }

    @discardableResult
    func updateVoiceMemoTitle(id: VoiceMemo.ID, title: String, updatedAt: Date = .now) async -> Bool {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedTitle.isEmpty else {
            errorMessage = "Voice memo title cannot be empty."
            return false
        }

        guard let voiceMemoIndex = voiceMemos.firstIndex(where: { $0.id == id }) else {
            errorMessage = "Tick could not find that voice memo."
            return false
        }

        voiceMemos[voiceMemoIndex].title = trimmedTitle
        voiceMemos[voiceMemoIndex].updatedAt = updatedAt
        voiceMemos.sort { $0.createdAt > $1.createdAt }
        await persistVoiceMemos(audioFileNamesToSync: [])
        return true
    }

    @discardableResult
    func deleteVoiceMemo(id: VoiceMemo.ID) async -> Bool {
        guard let voiceMemoIndex = voiceMemos.firstIndex(where: { $0.id == id }) else {
            errorMessage = "Tick could not find that voice memo."
            return false
        }

        let voiceMemo = voiceMemos.remove(at: voiceMemoIndex)

        if playingVoiceMemoID == id {
            voiceMemoAudioController.stopPlaying()
            playingVoiceMemoID = nil
        }

        await persistVoiceMemos(deletedVoiceMemoIDs: [id])
        await deleteVoiceMemoFiles([voiceMemo])
        return true
    }

    @discardableResult
    func updateSession(
        id: TimeSession.ID,
        title: String,
        notes: String,
        projectID: TickProject.ID
    ) async -> Bool {
        guard projects.contains(where: { $0.id == projectID }) else {
            errorMessage = "Choose a space for this Tick."
            return false
        }

        guard let sessionIndex = sessions.firstIndex(where: { $0.id == id }) else {
            errorMessage = "Tick could not find that session."
            return false
        }

        sessions[sessionIndex].title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        sessions[sessionIndex].notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        sessions[sessionIndex].projectID = projectID
        sessions.sort { $0.referenceDate > $1.referenceDate }
        await persist()
        return true
    }

    @discardableResult
    func deleteSession(id: TimeSession.ID) async -> Bool {
        guard let sessionIndex = sessions.firstIndex(where: { $0.id == id }) else {
            errorMessage = "Tick could not find that session."
            return false
        }

        guard !sessions[sessionIndex].isActive else {
            errorMessage = "Stop the active Tick before deleting it."
            return false
        }

        sessions.remove(at: sessionIndex)
        await persist()
        return true
    }

    func sessions(on date: Date, calendar: Calendar = .current) -> [TimeSession] {
        sessions
            .filter { calendar.isDate($0.referenceDate, inSameDayAs: date) }
            .sorted { $0.referenceDate > $1.referenceDate }
    }

    func totalDuration(on date: Date, at displayDate: Date = .now, calendar: Calendar = .current) -> TimeInterval {
        sessions(on: date, calendar: calendar).reduce(0) { total, session in
            total + session.duration(at: displayDate)
        }
    }

    func totalDuration(for projectID: TickProject.ID, at displayDate: Date = .now) -> TimeInterval {
        sessions
            .filter { $0.projectID == projectID }
            .reduce(0) { total, session in
                total + session.duration(at: displayDate)
            }
    }

    func summary(for period: SummaryPeriod, at date: Date = .now, calendar: Calendar = .current) -> TickSummary {
        TickSummaryCalculator.summary(
            for: period,
            projects: projects,
            sessions: sessions,
            referenceDate: date,
            calendar: calendar
        )
    }

    func clearError() {
        errorMessage = nil
    }

    private func persist() async {
        let snapshot = TickStorageSnapshot(
            projects: projects,
            sessions: sessions,
            autoTickRules: autoTickRules
        )

        do {
            try await store.save(snapshot)
            do {
                try iCloudSyncStore?.save(snapshot)
                errorMessage = nil
            } catch {
                errorMessage = "Tick saved locally but could not sync with iCloud. \(error.localizedDescription)"
            }
            refreshAutoTickMonitoring()
            await refreshWidgetSnapshot()
        } catch {
            errorMessage = "Tick could not save your changes. \(error.localizedDescription)"
        }
    }

    @discardableResult
    private func persistVoiceMemos(
        deletedVoiceMemoIDs: [VoiceMemo.ID] = [],
        audioFileNamesToSync: Set<String>? = nil
    ) async -> Bool {
        do {
            let snapshot = try await voiceMemoStore.save(
                voiceMemos,
                deletedVoiceMemoIDs: deletedVoiceMemoIDs,
                audioFileNamesToSync: audioFileNamesToSync
            )
            try voiceMemoICloudSyncStore?.save(snapshot)
            errorMessage = nil
            return true
        } catch {
            errorMessage = "Tick could not save your voice memos. \(error.localizedDescription)"
            return false
        }
    }

    private func reloadVoiceMemos() async {
        do {
            let localSnapshot = try await voiceMemoStore.loadSnapshot()
            let resolvedSnapshot = try await resolveVoiceMemoICloudSnapshot(localSnapshot)
            voiceMemos = resolvedSnapshot.voiceMemos.sorted { $0.createdAt > $1.createdAt }
        } catch {
            errorMessage = "Tick could not load saved voice memos. \(error.localizedDescription)"
        }
    }

    private func resolveVoiceMemoICloudSnapshot(
        _ localSnapshot: TickVoiceMemoStorageSnapshot
    ) async throws -> TickVoiceMemoStorageSnapshot {
        guard let voiceMemoICloudSyncStore else {
            return localSnapshot
        }

        guard let remoteSnapshot = try voiceMemoICloudSyncStore.loadSnapshot() else {
            if !localSnapshot.isEmpty {
                try voiceMemoICloudSyncStore.save(localSnapshot)
            }

            return localSnapshot
        }

        let resolvedSnapshot = TickVoiceMemoStore.merged(localSnapshot, remoteSnapshot)

        if resolvedSnapshot != localSnapshot {
            try await voiceMemoStore.save(resolvedSnapshot)
        }

        if resolvedSnapshot != remoteSnapshot {
            try voiceMemoICloudSyncStore.save(resolvedSnapshot)
        }

        return resolvedSnapshot
    }

    private func deleteVoiceMemoFiles(_ voiceMemos: [VoiceMemo]) async {
        do {
            try await voiceMemoStore.deleteAudioFiles(for: voiceMemos)
        } catch {
            errorMessage = "Tick removed the voice memo record but could not delete the audio file. \(error.localizedDescription)"
        }
    }

    private func resolveICloudSnapshot(
        localSnapshot: TickStorageSnapshot,
        localModifiedAt: Date?
    ) async -> TickStorageSnapshot {
        guard let iCloudSyncStore else {
            return localSnapshot
        }

        do {
            let resolution = iCloudSyncStore.resolve(
                localSnapshot: localSnapshot,
                localModifiedAt: localModifiedAt,
                remoteEnvelope: try iCloudSyncStore.loadEnvelope()
            )

            if resolution.shouldSaveLocal {
                try await store.save(resolution.snapshot)
            }

            if resolution.shouldSaveRemote {
                try iCloudSyncStore.save(resolution.snapshot)
            }

            return resolution.snapshot
        } catch {
            errorMessage = "Tick could not sync iCloud data. \(error.localizedDescription)"
            return localSnapshot
        }
    }

    private func applyRemoteICloudSnapshotIfNeeded() async {
        do {
            let localSnapshot = try await store.load()
            let localModifiedAt = try? await store.modificationDate()
            let resolvedSnapshot = await resolveICloudSnapshot(
                localSnapshot: localSnapshot,
                localModifiedAt: localModifiedAt
            )

            if resolvedSnapshot != currentStorageSnapshot {
                apply(storageSnapshot: resolvedSnapshot)
                refreshAutoTickMonitoring()
                await refreshWidgetSnapshot()
            }
        } catch {
            errorMessage = "Tick could not apply iCloud changes. \(error.localizedDescription)"
        }
    }

    private var currentStorageSnapshot: TickStorageSnapshot {
        TickStorageSnapshot(
            projects: projects,
            sessions: sessions,
            autoTickRules: autoTickRules
        )
    }

    private func clearVoiceMemoRecordingState() {
        recordingVoiceMemoID = nil
        recordingVoiceMemoFileName = nil
        recordingVoiceMemoStartedAt = nil
        recordingVoiceMemoProjectID = nil
    }

    private func apply(storageSnapshot: TickStorageSnapshot) {
        projects = TickProject.sortedByDisplayOrder(storageSnapshot.projects)
        sessions = storageSnapshot.sessions.sorted { $0.referenceDate > $1.referenceDate }
        autoTickRules = storageSnapshot.autoTickRules.sorted { $0.createdAt < $1.createdAt }

        if let activeSession {
            selectedProjectID = activeSession.projectID
        } else if let selectedProjectID {
            if !activeProjects.contains(where: { $0.id == selectedProjectID }) {
                self.selectedProjectID = activeProjects.first?.id
            }
        } else {
            selectedProjectID = activeProjects.first?.id
        }
    }

    func refreshWidgetSnapshot(at date: Date = .now) async {
        let widgetStorageSnapshot = TickWidgetStorageSnapshot(
            projects: projects.map { project in
                TickWidgetStoredProject(
                    id: project.id,
                    name: project.name,
                    createdAt: project.createdAt,
                    isArchived: project.isArchived,
                    sortOrder: project.sortOrder
                )
            },
            sessions: sessions.map { session in
                TickWidgetStoredSession(
                    id: session.id,
                    projectID: session.projectID,
                    title: session.title,
                    notes: session.notes,
                    startedAt: session.startedAt,
                    endedAt: session.endedAt,
                    manualDuration: session.manualDuration,
                    pausedAt: session.pausedAt,
                    accumulatedPausedDuration: session.accumulatedPausedDuration,
                    entrySource: session.entrySource.rawValue,
                    autoTickRuleID: session.autoTickRuleID,
                    createdAt: session.createdAt
                )
            },
            autoTickRules: autoTickRules.map { rule in
                TickWidgetStoredAutoTickRule(
                    id: rule.id,
                    projectID: rule.projectID,
                    name: rule.name,
                    latitude: rule.latitude,
                    longitude: rule.longitude,
                    radiusMeters: rule.radiusMeters,
                    startsOnArrival: rule.startsOnArrival,
                    stopsOnDeparture: rule.stopsOnDeparture,
                    isEnabled: rule.isEnabled,
                    createdAt: rule.createdAt
                )
            }
        )
        let widgetSnapshot = TickWidgetSnapshotBuilder.snapshot(
            from: widgetStorageSnapshot,
            defaultProjectID: selectedProjectID,
            at: date
        )

        do {
            try TickWidgetActionStore().saveWidgetSnapshot(widgetSnapshot)
            WidgetCenter.shared.reloadAllTimelines()
        } catch {
            errorMessage = "Tick could not update the widget. \(error.localizedDescription)"
        }
    }

    private func startAutoTickIfNeeded(for rule: AutoTickRule, at date: Date) async -> Bool {
        guard rule.startsOnArrival else {
            return false
        }

        guard activeSession == nil else {
            return false
        }

        let session = TimeSession(
            projectID: rule.projectID,
            title: rule.name,
            notes: "Started automatically by Auto Ticks.",
            startedAt: date,
            endedAt: nil,
            manualDuration: nil,
            entrySource: .autoLocation,
            autoTickRuleID: rule.id,
            createdAt: date
        )
        sessions.insert(session, at: 0)
        await persist()
        return true
    }

    private func stopAutoTickIfNeeded(for rule: AutoTickRule, at date: Date) async -> Bool {
        guard rule.stopsOnDeparture else {
            return false
        }

        guard let sessionIndex = sessions.firstIndex(where: {
            $0.isActive &&
                $0.entrySource == .autoLocation &&
                $0.autoTickRuleID == rule.id
        }) else {
            return false
        }

        let startedAt = sessions[sessionIndex].startedAt ?? date
        let pauseDate = sessions[sessionIndex].pausedAt
        let endedAt = pauseDate ?? date
        sessions[sessionIndex].endedAt = endedAt < startedAt ? startedAt : endedAt
        sessions[sessionIndex].pausedAt = nil
        sessions.sort { $0.referenceDate > $1.referenceDate }
        await persist()
        return true
    }

    private func apply(locationState: AutoTickLocationState) {
        let previousAuthorizationStatus = autoTickLocationAuthorizationStatus
        autoTickLocationAuthorizationStatus = locationState.authorizationStatus
        latestAutoTickCoordinate = locationState.latestCoordinate
        autoTickLocationMessage = locationState.statusMessage
        autoTickLocationErrorMessage = locationState.errorMessage

        if previousAuthorizationStatus != locationState.authorizationStatus {
            refreshAutoTickMonitoring()
        }
    }

    private func refreshAutoTickMonitoring() {
        locationService.refreshMonitoring(for: autoTickRules)
    }
}

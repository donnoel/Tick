import Foundation
import Observation

@MainActor
@Observable
final class TickViewModel {
    private let store: TickDataStore
    private let locationService: AutoTickLocationService

    private(set) var projects: [TickProject] = []
    private(set) var sessions: [TimeSession] = []
    private(set) var autoTickRules: [AutoTickRule] = []
    private(set) var autoTickLocationAuthorizationStatus: AutoTickLocationAuthorizationStatus
    private(set) var latestAutoTickCoordinate: AutoTickCoordinate?
    private(set) var autoTickLocationMessage: String
    private(set) var autoTickLocationErrorMessage: String?
    var selectedProjectID: TickProject.ID?
    var errorMessage: String?
    private(set) var hasLoaded = false

    init(store: TickDataStore = TickDataStore()) {
        let locationService = AutoTickLocationService()
        self.store = store
        self.locationService = locationService

        let locationState = locationService.currentState
        self.autoTickLocationAuthorizationStatus = locationState.authorizationStatus
        self.latestAutoTickCoordinate = locationState.latestCoordinate
        self.autoTickLocationMessage = locationState.statusMessage
        self.autoTickLocationErrorMessage = locationState.errorMessage

        configureLocationServiceCallbacks()
    }

    init(store: TickDataStore, locationService: AutoTickLocationService) {
        self.store = store
        self.locationService = locationService

        let locationState = locationService.currentState
        self.autoTickLocationAuthorizationStatus = locationState.authorizationStatus
        self.latestAutoTickCoordinate = locationState.latestCoordinate
        self.autoTickLocationMessage = locationState.statusMessage
        self.autoTickLocationErrorMessage = locationState.errorMessage

        configureLocationServiceCallbacks()
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

    var activeProjects: [TickProject] {
        projects
            .filter { !$0.isArchived }
            .sorted { lhs, rhs in
                lhs.createdAt < rhs.createdAt
            }
    }

    var activeSession: TimeSession? {
        sessions.first { $0.isActive }
    }

    func loadIfNeeded() async {
        guard !hasLoaded else {
            return
        }

        do {
            let snapshot = try await store.load()
            projects = snapshot.projects.sorted { $0.createdAt < $1.createdAt }
            sessions = snapshot.sessions.sorted { $0.referenceDate > $1.referenceDate }
            autoTickRules = snapshot.autoTickRules.sorted { $0.createdAt < $1.createdAt }
            selectedProjectID = activeSession?.projectID ?? activeProjects.first?.id
            hasLoaded = true
            refreshAutoTickMonitoring()
        } catch {
            errorMessage = "Tick could not load saved time. \(error.localizedDescription)"
            hasLoaded = true
        }
    }

    @discardableResult
    func addProject(name: String, createdAt: Date = .now) async -> Bool {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedName.isEmpty else {
            errorMessage = "Project name cannot be empty."
            return false
        }

        let project = TickProject(name: trimmedName, createdAt: createdAt)
        projects.append(project)
        projects.sort { $0.createdAt < $1.createdAt }

        if selectedProjectID == nil {
            selectedProjectID = project.id
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
            errorMessage = "Choose or create a project before starting Tick."
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
        sessions[activeIndex].endedAt = date < startedAt ? startedAt : date
        sessions.sort { $0.referenceDate > $1.referenceDate }
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
            errorMessage = "Choose a project for this manual time."
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
            errorMessage = "Choose a project for this Auto Tick."
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

    func session(for id: TimeSession.ID) -> TimeSession? {
        sessions.first { $0.id == id }
    }

    @discardableResult
    func updateSession(
        id: TimeSession.ID,
        title: String,
        notes: String,
        projectID: TickProject.ID
    ) async -> Bool {
        guard projects.contains(where: { $0.id == projectID }) else {
            errorMessage = "Choose a project for this Tick."
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
        do {
            try await store.save(
                TickStorageSnapshot(
                    projects: projects,
                    sessions: sessions,
                    autoTickRules: autoTickRules
                )
            )
            errorMessage = nil
            refreshAutoTickMonitoring()
        } catch {
            errorMessage = "Tick could not save your changes. \(error.localizedDescription)"
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
        sessions[sessionIndex].endedAt = date < startedAt ? startedAt : date
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

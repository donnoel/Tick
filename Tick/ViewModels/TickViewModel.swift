import Foundation
import Observation

@MainActor
@Observable
final class TickViewModel {
    private let store: TickDataStore

    private(set) var projects: [TickProject] = []
    private(set) var sessions: [TimeSession] = []
    var selectedProjectID: TickProject.ID?
    var errorMessage: String?
    private(set) var hasLoaded = false

    init(store: TickDataStore = TickDataStore()) {
        self.store = store
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
            selectedProjectID = activeSession?.projectID ?? activeProjects.first?.id
            hasLoaded = true
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
            try await store.save(TickStorageSnapshot(projects: projects, sessions: sessions))
            errorMessage = nil
        } catch {
            errorMessage = "Tick could not save your changes. \(error.localizedDescription)"
        }
    }
}

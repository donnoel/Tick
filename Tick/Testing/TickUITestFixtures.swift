#if UITEST_FIXTURES
import Foundation

nonisolated enum TickUITestFixture: String, CaseIterable {
    case capture
    case manualEditing
    case timingEditing
    case projectDeletion
    case todayDeletion
    case twoSpaces
    case iPadAlignment
    case todayTotals
    case summaryReport
}

nonisolated enum TickUITestFixtureInstaller {
    static let argument = "-uiTestFixture"

    enum FixtureError: LocalizedError {
        case invalidName
        case missingIsolationArguments

        var errorDescription: String? {
            switch self {
            case .invalidName:
                "A valid UI-test fixture name must follow \(TickUITestFixtureInstaller.argument)."
            case .missingIsolationArguments:
                "UI-test fixtures require reset and disabled-cloud launch arguments."
            }
        }
    }

    static func installIfRequested(
        arguments: [String] = ProcessInfo.processInfo.arguments,
        now: Date = .now,
        fileManager: FileManager = .default
    ) throws {
        guard let argumentIndex = arguments.firstIndex(of: argument) else { return }
        guard arguments.indices.contains(argumentIndex + 1),
              let fixture = TickUITestFixture(rawValue: arguments[argumentIndex + 1]) else {
            throw FixtureError.invalidName
        }
        guard arguments.contains("-resetDataForUITests"),
              arguments.contains("-disableCloudSyncForUITests") else {
            throw FixtureError.missingIsolationArguments
        }

        let fileURL = TickSharedStorage.dataFileURL(fileManager: fileManager)
        try fileManager.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let envelope = TickStorageFileEnvelope(
            updatedAt: now,
            snapshot: snapshot(for: fixture, now: now)
        )
        try encoder.encode(envelope).write(to: fileURL, options: .atomic)
    }

    static func snapshot(for fixture: TickUITestFixture, now: Date) -> TickStorageSnapshot {
        switch fixture {
        case .capture:
            let project = project(id: 1, name: "Design Studio", order: 0, now: now)
            return TickStorageSnapshot(projects: [project], sessions: [])
        case .manualEditing:
            let project = project(id: 1, name: "Manual UI Project", order: 0, now: now)
            let session = manualSession(
                id: 101, projectID: project.id, title: "Manual UI Session",
                notes: "Logged from UI test", now: now
            )
            return TickStorageSnapshot(projects: [project], sessions: [session])
        case .timingEditing:
            let project = project(id: 1, name: "Timing Project", order: 0, now: now)
            let session = manualSession(
                id: 101, projectID: project.id, title: "Timing work", now: now
            )
            return TickStorageSnapshot(projects: [project], sessions: [session])
        case .projectDeletion:
            let project = project(id: 1, name: "Delete UI Project", order: 0, now: now)
            let session = manualSession(
                id: 101, projectID: project.id, title: "Delete UI Session", now: now
            )
            return TickStorageSnapshot(projects: [project], sessions: [session])
        case .todayDeletion:
            let project = project(id: 1, name: "Today Delete Space", order: 0, now: now)
            let session = manualSession(
                id: 101, projectID: project.id, title: "Today Delete Tick", now: now
            )
            return TickStorageSnapshot(projects: [project], sessions: [session])
        case .twoSpaces:
            return TickStorageSnapshot(
                projects: [
                    project(id: 1, name: "Puzzles", order: 0, now: now),
                    project(id: 2, name: "Ticks", order: 1, now: now),
                ],
                sessions: []
            )
        case .iPadAlignment:
            let puzzles = project(id: 1, name: "Puzzles", order: 0, now: now)
            let ticks = project(id: 2, name: "Ticks", order: 1, now: now)
            return TickStorageSnapshot(
                projects: [puzzles, ticks],
                sessions: [
                    manualSession(id: 101, projectID: puzzles.id, title: "Short task", now: now),
                    manualSession(
                        id: 102, projectID: ticks.id,
                        title: "A detailed project description that would otherwise wrap over several lines in the Today grid",
                        now: now
                    ),
                ]
            )
        case .todayTotals:
            let puzzles = project(id: 1, name: "Puzzles", order: 0, now: now)
            let tonight = project(id: 2, name: "Tonight", order: 1, now: now)
            return TickStorageSnapshot(
                projects: [puzzles, tonight],
                sessions: [manualSession(
                    id: 101, projectID: puzzles.id, title: "Planning", now: now
                )]
            )
        case .summaryReport:
            let planning = project(id: 1, name: "Planning report", order: 0, now: now)
            let review = project(id: 2, name: "Review report", order: 1, now: now)
            let client = project(id: 3, name: "Client report", order: 2, now: now)
            return TickStorageSnapshot(
                projects: [planning, review, client],
                sessions: [
                    manualSession(id: 101, projectID: planning.id, title: "Project planning", now: now),
                    manualSession(id: 102, projectID: review.id, title: "Project planning", now: now),
                    manualSession(
                        id: 103, projectID: client.id,
                        title: "Implementation and testing", now: now
                    ),
                ]
            )
        }
    }

    private static func project(id: Int, name: String, order: Double, now: Date) -> TickProject {
        TickProject(
            id: uuid(id),
            name: name,
            createdAt: now.addingTimeInterval(order),
            sortOrder: order
        )
    }

    private static func manualSession(
        id: Int,
        projectID: TickProject.ID,
        title: String,
        notes: String = "",
        now: Date
    ) -> TimeSession {
        TimeSession(
            id: uuid(id),
            projectID: projectID,
            title: title,
            notes: notes,
            startedAt: now,
            endedAt: nil,
            manualDuration: 30 * 60,
            entrySource: .manual,
            createdAt: now
        )
    }

    private static func uuid(_ value: Int) -> UUID {
        UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", value))!
    }
}
#endif

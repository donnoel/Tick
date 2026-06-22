import Foundation

nonisolated struct TickWidgetActionResult: Equatable {
    var didChange: Bool
    var message: String
}

nonisolated final class TickWidgetActionStore {
    private let dataFileURL: URL
    private let widgetSnapshotFileURL: URL
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder
    private let fileManager: FileManager
    private let iCloudSyncStore: TickWidgetICloudSyncStore?

    convenience init() {
        self.init(
            dataFileURL: TickSharedStorage.dataFileURL(),
            widgetSnapshotFileURL: TickSharedStorage.widgetSnapshotFileURL(),
            fileManager: .default,
            iCloudSyncStore: TickWidgetICloudSyncStore()
        )
    }

    init(
        dataFileURL: URL,
        widgetSnapshotFileURL: URL,
        fileManager: FileManager = .default,
        iCloudSyncStore: TickWidgetICloudSyncStore? = nil
    ) {
        self.dataFileURL = dataFileURL
        self.widgetSnapshotFileURL = widgetSnapshotFileURL
        self.fileManager = fileManager
        self.iCloudSyncStore = iCloudSyncStore

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.encoder = encoder
    }

    func loadWidgetSnapshot(at date: Date = .now, calendar: Calendar = .current) throws -> TickWidgetSnapshot {
        if let cachedSnapshot = try loadCachedWidgetSnapshot() {
            if let reconciledSnapshot = try? reconciledWidgetSnapshot(
                for: cachedSnapshot,
                at: date,
                calendar: calendar
            ) {
                return reconciledSnapshot
            }

            return cachedSnapshot
        }

        let storageSnapshot = try loadStorageSnapshot()
        return TickWidgetSnapshotBuilder.snapshot(
            from: storageSnapshot,
            defaultProjectID: nil,
            at: date,
            calendar: calendar
        )
    }

    private func reconciledWidgetSnapshot(
        for cachedSnapshot: TickWidgetSnapshot,
        at date: Date,
        calendar: Calendar
    ) throws -> TickWidgetSnapshot? {
        let storageSnapshot = try loadStorageSnapshot()
        let currentSnapshot = TickWidgetSnapshotBuilder.snapshot(
            from: storageSnapshot,
            defaultProjectID: cachedSnapshot.defaultProjectID,
            at: date,
            calendar: calendar
        )

        guard currentSnapshot.activeSessionID != cachedSnapshot.activeSessionID ||
            currentSnapshot.activePausedAt != cachedSnapshot.activePausedAt else {
            return nil
        }

        return currentSnapshot
    }

    func saveWidgetSnapshot(_ snapshot: TickWidgetSnapshot) throws {
        try fileManager.createDirectory(
            at: widgetSnapshotFileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let data = try encoder.encode(snapshot)
        try TickSharedFileCoordinator.coordinateWriting(at: widgetSnapshotFileURL) { coordinatedURL in
            try data.write(to: coordinatedURL, options: [.atomic])
        }
    }

    @discardableResult
    func startTick(at date: Date = .now, calendar: Calendar = .current) throws -> TickWidgetActionResult {
        try TickSharedFileCoordinator.coordinateWriting(at: dataFileURL) { coordinatedDataFileURL in
            var storageSnapshot = try loadStorageSnapshot(from: coordinatedDataFileURL)

            guard storageSnapshot.sessions.first(where: \.isActive) == nil else {
                return TickWidgetActionResult(didChange: false, message: "A Tick is already running.")
            }

            let activeProjects = storageSnapshot.projects
                .filter { !$0.isArchived }
                .sorted { lhs, rhs in
                    if lhs.sortOrder == rhs.sortOrder {
                        return lhs.createdAt < rhs.createdAt
                    }

                    return lhs.sortOrder < rhs.sortOrder
                }

            guard !activeProjects.isEmpty else {
                try saveWidgetSnapshot(.empty(lastUpdatedAt: date))
                return TickWidgetActionResult(didChange: false, message: "Open Ticks to create a space first.")
            }

            let existingSnapshot = try? loadCachedWidgetSnapshot()
            let selectedProject = activeProjects.first { $0.id == existingSnapshot?.defaultProjectID } ?? activeProjects[0]
            let session = TickWidgetStoredSession(
                id: UUID(),
                projectID: selectedProject.id,
                title: "",
                notes: "",
                startedAt: date,
                endedAt: nil,
                manualDuration: nil,
                entrySource: "timer",
                autoTickRuleID: nil,
                createdAt: date
            )

            storageSnapshot.sessions.insert(session, at: 0)
            try saveStorageSnapshot(storageSnapshot, to: coordinatedDataFileURL)
            try saveWidgetSnapshot(
                TickWidgetSnapshotBuilder.snapshot(
                    from: storageSnapshot,
                    defaultProjectID: selectedProject.id,
                    at: date,
                    calendar: calendar
                )
            )
            return TickWidgetActionResult(didChange: true, message: "Started Tick.")
        }
    }

    @discardableResult
    func stopTick(at date: Date = .now, calendar: Calendar = .current) throws -> TickWidgetActionResult {
        try TickSharedFileCoordinator.coordinateWriting(at: dataFileURL) { coordinatedDataFileURL in
            var storageSnapshot = try loadStorageSnapshot(from: coordinatedDataFileURL)

            guard let activeIndex = storageSnapshot.sessions.firstIndex(where: \.isActive) else {
                return TickWidgetActionResult(didChange: false, message: "No Tick is running.")
            }

            let startedAt = storageSnapshot.sessions[activeIndex].startedAt ?? date
            storageSnapshot.sessions[activeIndex].endedAt = date < startedAt ? startedAt : date
            storageSnapshot.sessions.sort { $0.referenceDate > $1.referenceDate }

            let existingSnapshot = try? loadCachedWidgetSnapshot()
            try saveStorageSnapshot(storageSnapshot, to: coordinatedDataFileURL)
            try saveWidgetSnapshot(
                TickWidgetSnapshotBuilder.snapshot(
                    from: storageSnapshot,
                    defaultProjectID: existingSnapshot?.defaultProjectID,
                    at: date,
                    calendar: calendar
                )
            )
            return TickWidgetActionResult(didChange: true, message: "Stopped Tick.")
        }
    }

    func loadStorageSnapshot() throws -> TickWidgetStorageSnapshot {
        try TickSharedFileCoordinator.coordinateReading(at: dataFileURL) { coordinatedDataFileURL in
            try loadStorageSnapshot(from: coordinatedDataFileURL)
        }
    }

    private func loadCachedWidgetSnapshot() throws -> TickWidgetSnapshot? {
        guard fileManager.fileExists(atPath: widgetSnapshotFileURL.path) else {
            return nil
        }

        let data = try TickSharedFileCoordinator.coordinateReading(at: widgetSnapshotFileURL) { coordinatedURL in
            try Data(contentsOf: coordinatedURL)
        }

        guard !data.isEmpty else {
            return nil
        }

        return try decoder.decode(TickWidgetSnapshot.self, from: data)
    }

    private func loadStorageSnapshot(from fileURL: URL) throws -> TickWidgetStorageSnapshot {
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return .empty
        }

        let data = try Data(contentsOf: fileURL)

        guard !data.isEmpty else {
            return .empty
        }

        return try decoder.decode(TickWidgetStorageSnapshot.self, from: data)
    }

    private func saveStorageSnapshot(_ snapshot: TickWidgetStorageSnapshot, to fileURL: URL) throws {
        try fileManager.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let data = try encoder.encode(snapshot)
        try data.write(to: fileURL, options: [.atomic])
        try iCloudSyncStore?.save(snapshot)
    }
}

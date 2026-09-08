import Foundation
import XCTest
@testable import Tick

final class TickProjectPilotIntegrationTests: XCTestCase {
    func testWidgetStopUsesTheSamePausedDurationAsTheApp() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let dataURL = directory.appendingPathComponent("tick-data.json")
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let project = TickWidgetStoredProject(id: UUID(), name: "Beam", createdAt: date, isArchived: false)
        var snapshot = TickWidgetStorageSnapshot(projects: [project], sessions: [])
        try TickTimerMutation.start(in: &snapshot, projectID: project.id, at: date)
        snapshot.sessions[0].pausedAt = date.addingTimeInterval(100)
        snapshot.sessions[0].accumulatedPausedDuration = 20
        try TickCloudCodec.encode(snapshot).write(to: dataURL, options: .atomic)
        let store = TickWidgetActionStore(dataFileURL: dataURL,
                                         widgetSnapshotFileURL: directory.appendingPathComponent("widget.json"))
        XCTAssertTrue(try store.stopTick(at: date.addingTimeInterval(200)).didChange)
        let saved = try store.loadStorageSnapshot()
        XCTAssertEqual(saved.sessions[0].duration(at: date.addingTimeInterval(300)), 80)
        XCTAssertNil(saved.sessions[0].pausedAt)
        XCTAssertFalse(saved.sessions[0].isActive)
    }
}

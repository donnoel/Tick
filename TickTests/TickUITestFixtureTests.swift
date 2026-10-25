#if UITEST_FIXTURES
import XCTest
@testable import Tick

final class TickUITestFixtureTests: XCTestCase {
    func testEveryFixtureHasValidReferentialIntegrityAndRoundTrips() throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        for fixture in TickUITestFixture.allCases {
            let snapshot = TickUITestFixtureInstaller.snapshot(for: fixture, now: now)
            let projectIDs = Set(snapshot.projects.map(\.id))
            XCTAssertTrue(
                snapshot.sessions.allSatisfy { projectIDs.contains($0.projectID) },
                "Fixture \(fixture.rawValue) contains an orphaned session"
            )
            XCTAssertLessThanOrEqual(snapshot.sessions.filter(\.isActive).count, 2)

            let data = try encoder.encode(snapshot)
            XCTAssertEqual(try decoder.decode(TickStorageSnapshot.self, from: data), snapshot)
        }
    }
}
#endif

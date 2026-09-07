import CloudKit
import XCTest
@testable import Tick

final class TickCloudFailureTests: XCTestCase {
    func testDirectCASConflictRetries() {
        XCTAssertTrue(TickCloudFailure.isConflict(CKError(.serverRecordChanged)))
    }

    func testAtomicBatchCASConflictRetries() {
        let error = CKError(.partialFailure, userInfo: [CKPartialErrorsByItemIDKey:
            [CKRecord.ID(recordName: "snapshot-v1"): CKError(.serverRecordChanged)]])
        XCTAssertTrue(TickCloudFailure.isConflict(error))
    }

    func testContainerPermissionFailureIsNotMisreportedAsCASConflict() {
        let error = CKError(.partialFailure, userInfo: [CKPartialErrorsByItemIDKey:
            [CKRecord.ID(recordName: "snapshot-v1"): CKError(.permissionFailure)]])
        XCTAssertFalse(TickCloudFailure.isConflict(error))
        XCTAssertTrue(TickCloudFailure.diagnostic(error).contains("CKErrorDomain:10"))
    }
}

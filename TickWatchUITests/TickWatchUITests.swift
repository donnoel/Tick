import XCTest

nonisolated final class TickWatchUITests: XCTestCase {
    @MainActor func testChooseSpaceStartPauseResumeStopAndRelaunch() {
        let app = XCUIApplication()
        app.launchArguments = ["-watchPreviewFixture", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryXXXL"]
        app.launch()
        if app.buttons["Stop Tick"].waitForExistence(timeout: 2) { app.buttons["Stop Tick"].tap() }
        XCTAssertTrue(app.buttons["Start Tick"].waitForExistence(timeout: 10))
        app.buttons["Choose Space"].tap()
        XCTAssertTrue(app.buttons["Mosa"].waitForExistence(timeout: 5))
        app.buttons["Mosa"].tap()
        XCTAssertTrue(app.buttons["Start Tick"].waitForExistence(timeout: 5))
        app.buttons["Start Tick"].tap()
        XCTAssertTrue(app.buttons["Pause Tick"].waitForExistence(timeout: 5))
        let pause = app.buttons["Pause Tick"]
        let stop = app.buttons["Stop Tick"]
        XCTAssertTrue(pause.isHittable)
        XCTAssertTrue(stop.isHittable)
        XCTAssertEqual(pause.frame.midY, stop.frame.midY, accuracy: 1)
        XCTAssertLessThanOrEqual(pause.frame.maxY, app.frame.maxY - 10)
        XCTAssertLessThanOrEqual(stop.frame.maxY, app.frame.maxY - 10)
        XCTAssertTrue(app.staticTexts["Active Space, Mosa"].exists)
        XCTAssertFalse(app.buttons["Choose Space"].exists)
        app.buttons["Pause Tick"].tap()
        XCTAssertTrue(app.buttons["Resume Tick"].waitForExistence(timeout: 5))
        app.terminate()
        app.launch()
        XCTAssertTrue(app.buttons["Resume Tick"].waitForExistence(timeout: 10))
        app.buttons["Resume Tick"].tap()
        XCTAssertTrue(app.buttons["Pause Tick"].waitForExistence(timeout: 5))
        app.buttons["Stop Tick"].tap()
        XCTAssertTrue(app.buttons["Start Tick"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons["Choose Space"].value as? String, "Mosa")
    }
}

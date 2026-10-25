import XCTest

nonisolated final class TickWatchUITests: XCTestCase {
    @MainActor func testTwoActiveTicksAreVisibleAndSelectable() {
        let app = XCUIApplication()
        app.launchArguments = ["-watchPreviewTwoActive"]
        app.launch()

        let choose = app.buttons["Choose Space"]
        XCTAssertTrue(choose.waitForExistence(timeout: 10))
        XCTAssertEqual(choose.value as? String, "Mosa, 2 Ticks active")
        XCTAssertTrue(app.buttons["Pause Tick"].exists)

        choose.tap()
        let mosa = app.buttons["Mosa"]
        let tick = app.buttons["Tick"]
        XCTAssertTrue(mosa.waitForExistence(timeout: 5))
        XCTAssertTrue(tick.waitForExistence(timeout: 5))
        XCTAssertTrue((mosa.value as? String)?.contains("Running") == true)
        XCTAssertTrue((tick.value as? String)?.contains("Running") == true)
        XCTAssertLessThan(mosa.frame.minY, app.buttons["Beam"].frame.minY)
        XCTAssertLessThan(tick.frame.minY, app.buttons["Beam"].frame.minY)
        tick.tap()
        XCTAssertEqual(choose.value as? String, "Tick, 2 Ticks active")
        XCTAssertTrue(app.buttons["Pause Tick"].exists)

        choose.tap()
        XCTAssertTrue(app.buttons["Beam"].waitForExistence(timeout: 5))
        app.buttons["Beam"].tap()
        let start = app.buttons["Start Tick"]
        XCTAssertTrue(start.waitForExistence(timeout: 5))
        XCTAssertFalse(start.isEnabled)
        XCTAssertEqual(choose.value as? String, "Beam, 2 Ticks active")

        app.terminate()
        app.launch()
        XCTAssertTrue(choose.waitForExistence(timeout: 10))
        XCTAssertEqual(choose.value as? String, "Mosa, 2 Ticks active")
        XCTAssertTrue(app.buttons["Pause Tick"].exists)
    }

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
        let readySpaceFrame = app.buttons["Choose Space"].frame
        let timer = app.descendants(matching: .any)["watch-timer"].firstMatch
        XCTAssertTrue(timer.waitForExistence(timeout: 5))
        let readyTimerFrame = timer.frame
        let startFrame = app.buttons["Start Tick"].frame
        attachScreenshot(app, name: "Ready")
        app.buttons["Start Tick"].tap()
        XCTAssertTrue(app.buttons["Pause Tick"].waitForExistence(timeout: 5))
        let pause = app.buttons["Pause Tick"]
        let stop = app.buttons["Stop Tick"]
        XCTAssertTrue(pause.isHittable)
        XCTAssertTrue(stop.isHittable)
        XCTAssertEqual(pause.frame.midY, stop.frame.midY, accuracy: 1)
        XCTAssertEqual(pause.frame.width, stop.frame.width, accuracy: 1)
        XCTAssertGreaterThanOrEqual(pause.frame.height, 44)
        XCTAssertEqual(pause.frame.minY, startFrame.minY, accuracy: 1)
        // The combined VoiceOver frame includes the status when it has text.
        // Its top edge tracks the timer line in every state.
        XCTAssertEqual(timer.frame.minY, readyTimerFrame.minY, accuracy: 1)
        XCTAssertLessThanOrEqual(pause.frame.maxY, app.frame.maxY - 10)
        XCTAssertLessThanOrEqual(stop.frame.maxY, app.frame.maxY - 10)
        XCTAssertEqual(app.buttons["Choose Space"].value as? String, "Mosa")
        XCTAssertEqual(app.buttons["Choose Space"].frame.midY, readySpaceFrame.midY, accuracy: 1)
        attachScreenshot(app, name: "Running")
        let pauseFrame = pause.frame
        app.buttons["Pause Tick"].tap()
        XCTAssertTrue(app.buttons["Resume Tick"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons["Resume Tick"].frame.minY, pauseFrame.minY, accuracy: 1)
        XCTAssertEqual(app.buttons["Resume Tick"].frame.width, pauseFrame.width, accuracy: 1)
        XCTAssertEqual(timer.frame.minY, readyTimerFrame.minY, accuracy: 1)
        attachScreenshot(app, name: "Paused")
        app.terminate()
        app.launch()
        XCTAssertTrue(app.buttons["Resume Tick"].waitForExistence(timeout: 10))
        app.buttons["Resume Tick"].tap()
        XCTAssertTrue(app.buttons["Pause Tick"].waitForExistence(timeout: 5))
        app.buttons["Stop Tick"].tap()
        XCTAssertTrue(app.buttons["Start Tick"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons["Choose Space"].value as? String, "Mosa")
    }

    @MainActor private func attachScreenshot(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}

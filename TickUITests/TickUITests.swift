import XCTest

final class TickUITests: XCTestCase {
    override func setUpWithError() throws {
        try super.setUpWithError()
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }

    func testPrivacyPolicyIsAvailableWithoutSpaces() throws {
        let app = launchResetApp()
        tab(named: "Spaces", in: app).tap()
        let privacy = app.buttons["projects.privacyPolicyButton"]
        XCTAssertTrue(privacy.waitForExistence(timeout: 5))
        privacy.tap()
        XCTAssertTrue(app.staticTexts["Your information"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["iCloud and your devices"].exists)
        let scrollView = app.scrollViews.firstMatch
        for _ in 0..<8 where !app.staticTexts["Policy updates"].isHittable {
            scrollView.swipeUp()
        }
        XCTAssertTrue(app.staticTexts["Policy updates"].isHittable)
        app.buttons["privacy.done"].tap()
        XCTAssertTrue(privacy.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["projects.addProjectButton"].isHittable)
    }

    func testCompactCapturePanelPreservesTimerAndManualEntryControls() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        let app = launchResetApp(fixture: .capture)
        tab(named: "Today", in: app).tap()

        func capture(_ name: String) {
            let attachment = XCTAttachment(screenshot: app.screenshot())
            attachment.name = name
            attachment.lifetime = .keepAlways
            add(attachment)
        }

        let start = app.buttons["today.playButton"]
        XCTAssertTrue(start.waitForExistence(timeout: 5))
        XCTAssertTrue(start.isHittable)
        capture("Compact timer - ready")
        start.tap()
        let pause = app.buttons["today.pauseButton"]
        XCTAssertTrue(pause.waitForExistence(timeout: 5))
        XCTAssertTrue(pause.waitUntilHittable(timeout: 5))
        capture("Compact timer - running")
        pause.tap()
        let resume = app.buttons["today.playButton"]
        XCTAssertTrue(resume.waitForExistence(timeout: 5))
        XCTAssertEqual(resume.label, "Resume Tick")
        capture("Compact timer - paused")
        resume.tap()
        XCTAssertTrue(pause.waitForExistence(timeout: 5))
        let stop = app.buttons["today.stopButton"]
        XCTAssertTrue(stop.waitUntilHittable(timeout: 5))
        stop.tap()
        XCTAssertTrue(start.waitForExistence(timeout: 5))
        XCTAssertEqual(start.label, "Start Tick")
        let addTime = app.buttons["today.addTimeButton"]
        XCTAssertTrue(addTime.isHittable)
        addTime.tap()
        XCTAssertTrue(app.textFields["manualTime.titleField"].waitForExistence(timeout: 5))
        app.buttons["Cancel"].tap()
        XCTAssertTrue(start.waitForExistence(timeout: 5))
        for title in ["Spaces", "Auto Ticks", "Summaries"] {
            tab(named: title, in: app).tap()
            capture("Pastel theme - \(title)")
        }
        tab(named: "Today", in: app).tap()
    }

    func testPrimaryTabsExist() throws {
        let app = launchResetApp()

        XCTAssertTrue(app.tabBars.buttons["Today"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.tabBars.buttons["Spaces"].exists)
        XCTAssertTrue(app.tabBars.buttons["Auto Ticks"].exists)
        XCTAssertTrue(app.tabBars.buttons["Summaries"].exists)
    }

    func testCreateProjectStartStopShowsTodaySessionRow() throws {
        let app = launchResetApp()

        let projectName = "UITest Project"
        let tabBar = app.tabBars.firstMatch

        createProject(named: projectName, in: app)

        let todayTab = tabBar.buttons["Today"]
        XCTAssertTrue(todayTab.waitForExistence(timeout: 5))
        todayTab.tap()

        let playButton = app.buttons["today.playButton"]
        XCTAssertTrue(playButton.waitForExistence(timeout: 5))
        XCTAssertEqual(playButton.label, "Start Tick")
        playButton.tap()

        let stopButton = app.buttons["today.stopButton"]
        XCTAssertTrue(stopButton.waitForExistence(timeout: 5))
        XCTAssertTrue(stopButton.waitUntilHittable(timeout: 5))
        stopButton.tap()

        XCTAssertTrue(app.buttons["Start Tick"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["today.sessionsHeader"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Ticking..."].waitForExistence(timeout: 5))
    }

    func testSpaceAndSessionPersistAfterRelaunch() throws {
        let app = launchResetApp()

        let projectName = "Persistent UI Project"
        let sessionTitle = "Persistent UI Session"

        createProject(named: projectName, in: app)
        addManualSession(titled: sessionTitle, in: app)

        app.terminate()
        app.launchArguments = ["-disableCloudSyncForUITests"]
        app.launch()

        let tabBar = app.tabBars.firstMatch
        let todayTab = tabBar.buttons["Today"]
        XCTAssertTrue(todayTab.waitForExistence(timeout: 5))
        todayTab.tap()

        XCTAssertTrue(app.staticTexts["today.sessionsHeader"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts[sessionTitle].waitForExistence(timeout: 5))

        let projectsTab = tabBar.buttons["Spaces"]
        XCTAssertTrue(projectsTab.waitForExistence(timeout: 5))
        projectsTab.tap()

        XCTAssertTrue(app.staticTexts[projectName].waitForExistence(timeout: 5))
    }

    func testAutoTicksEmptyAndAddRuleGuidanceWithoutLocation() throws {
        let app = launchResetApp()
        let tabBar = app.tabBars.firstMatch

        let autoTicksTab = tabBar.buttons["Auto Ticks"]
        XCTAssertTrue(autoTicksTab.waitForExistence(timeout: 5))
        autoTicksTab.tap()

        XCTAssertTrue(app.staticTexts["No Auto Ticks yet"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Add a place and Tick can start or stop for you."].exists)

        XCTAssertTrue(app.buttons["Add Auto Tick"].firstMatch.waitForExistence(timeout: 5))

        createProject(named: "Auto Tick UI Project", in: app)

        autoTicksTab.tap()
        let addAutoTickButton = app.buttons["Add Auto Tick"].firstMatch
        XCTAssertTrue(addAutoTickButton.waitForExistence(timeout: 5))
        XCTAssertTrue(addAutoTickButton.waitUntilEnabled(timeout: 5))
        addAutoTickButton.tap()

        XCTAssertTrue(app.staticTexts["New Auto Tick"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Location guidance"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Use Current Location"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.switches["Enabled"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Save"].isEnabled)
    }

    func testSelectedTabSurvivesHomePhotosAndRelaunch() throws {
        let app = launchResetApp()
        let photos = XCUIApplication(bundleIdentifier: "com.apple.mobileslideshow")
        app.launchArguments = ["-disableCloudSyncForUITests"]

        let summaries = app.tabBars.firstMatch.buttons["Summaries"]
        XCTAssertTrue(summaries.waitForExistence(timeout: 5))
        summaries.tap()
        XCTAssertTrue(summaries.isSelected)

        XCUIDevice.shared.press(.home)
        app.activate()
        XCTAssertTrue(app.tabBars.firstMatch.buttons["Summaries"].isSelected)

        photos.launch()
        app.activate()
        XCTAssertTrue(app.tabBars.firstMatch.buttons["Summaries"].isSelected)

        app.terminate()
        app.launch()
        XCTAssertTrue(app.tabBars.firstMatch.buttons["Summaries"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.tabBars.firstMatch.buttons["Summaries"].isSelected)
    }

    func testManualTimeSessionCanBeEditedFromSessionDetail() throws {
        let app = launchResetApp(fixture: .manualEditing)

        let initialSessionTitle = "Manual UI Session"
        let editedSessionTitle = "Edited Manual UI Session"

        let initialSessionRow = app.staticTexts[initialSessionTitle]
        XCTAssertTrue(initialSessionRow.waitForExistence(timeout: 5))
        initialSessionRow.tap()

        let detailTitleField = app.textFields["sessionDetail.titleField"]
        XCTAssertTrue(detailTitleField.waitForExistence(timeout: 5))
        detailTitleField.tap()
        detailTitleField.clearAndEnterText(editedSessionTitle)

        let detailSaveButton = app.buttons["sessionDetail.saveButton"]
        XCTAssertTrue(detailSaveButton.waitForExistence(timeout: 5))
        detailSaveButton.tap()

        XCTAssertTrue(app.staticTexts[editedSessionTitle].waitForExistence(timeout: 5))
    }

    func testSessionTimingEditsCanBeCancelledSavedAndRestored() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        let app = launchResetApp(fixture: .timingEditing)
        app.staticTexts["Timing work"].tap()
        XCTAssertTrue(app.datePickers["sessionDetail.date"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.datePickers["sessionDetail.start"].exists)

        let duration = app.descendants(matching: .any).matching(identifier: "sessionDetail.duration").firstMatch
        duration.tap()
        let minutes = app.steppers["sessionDetail.durationMinutes"]
        XCTAssertTrue(minutes.waitForExistence(timeout: 5))
        minutes.buttons["sessionDetail.durationMinutes-Increment"].tap()
        XCTAssertTrue(minutes.label.contains("31"))
        app.buttons["Cancel"].tap()

        XCTAssertTrue(app.staticTexts["Timing work"].waitForExistence(timeout: 5))
        app.staticTexts["Timing work"].tap()
        duration.tap()
        XCTAssertTrue(minutes.waitForExistence(timeout: 5))
        XCTAssertTrue(minutes.label.contains("30"))
        minutes.buttons["sessionDetail.durationMinutes-Increment"].tap()

        let source = app.buttons["sessionDetail.source"]
        source.tap()
        let timer = app.buttons["Timer"]
        XCTAssertTrue(timer.waitForExistence(timeout: 5))
        timer.tap()
        XCTAssertTrue(app.datePickers["sessionDetail.end"].waitForExistence(timeout: 5))
        app.buttons["sessionDetail.saveButton"].tap()
        XCTAssertTrue(app.staticTexts["Timing work"].waitForExistence(timeout: 5))

        app.terminate()
        app.launchArguments = ["-disableCloudSyncForUITests"]
        app.launch()
        XCTAssertTrue(app.staticTexts["Timing work"].waitForExistence(timeout: 5))
        app.staticTexts["Timing work"].tap()
        XCTAssertTrue(app.datePickers["sessionDetail.end"].waitForExistence(timeout: 5))
        duration.tap()
        XCTAssertTrue(minutes.label.contains("31"))
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Editable timing"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    func testProjectDetailSessionCanBeDeleted() throws {
        continueAfterFailure = false
        let app = launchResetApp(fixture: .projectDeletion)

        let sessionTitle = "Delete UI Session"
        let tabBar = app.tabBars.firstMatch

        let projectsTab = tabBar.buttons["Spaces"]
        XCTAssertTrue(projectsTab.waitForExistence(timeout: 5))
        projectsTab.tap()
        XCTAssertTrue(app.staticTexts["Delete UI Project"].waitForExistence(timeout: 5))
        app.staticTexts["Delete UI Project"].tap()

        let projectSessionRowText = app.staticTexts[sessionTitle]
        reveal(projectSessionRowText, in: app)
        XCTAssertTrue(projectSessionRowText.waitForExistence(timeout: 5))

        let projectSessionRow = app.cells.containing(.staticText, identifier: sessionTitle).firstMatch
        XCTAssertTrue(projectSessionRow.waitForExistence(timeout: 5))
        projectSessionRow.swipeLeft()
        let deleteButton = app.buttons["Delete"]
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 5))
        deleteButton.tap()

        let confirmation = app.alerts["Delete Tick?"]
        XCTAssertTrue(confirmation.waitForExistence(timeout: 5))
        XCTAssertTrue(confirmation.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", sessionTitle)).firstMatch.exists)
        XCTAssertTrue(projectSessionRowText.exists)

        let confirmationScreenshot = XCTAttachment(screenshot: app.screenshot())
        confirmationScreenshot.name = "Delete Tick confirmation"
        confirmationScreenshot.lifetime = .keepAlways
        add(confirmationScreenshot)

        confirmation.buttons["Cancel"].tap()
        XCTAssertTrue(confirmation.waitForNonExistence(timeout: 5))
        XCTAssertTrue(projectSessionRowText.exists)

        projectSessionRow.swipeLeft()
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 5))
        deleteButton.tap()
        XCTAssertTrue(confirmation.waitForExistence(timeout: 5))
        confirmation.buttons["Delete Tick"].tap()

        XCTAssertTrue(projectSessionRowText.waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["No Ticks yet"].waitForExistence(timeout: 5))
    }

    func testTodaySessionSwipeDeleteRequiresConfirmation() throws {
        continueAfterFailure = false
        let app = launchResetApp(fixture: .todayDeletion)

        let row = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "today.sessionRow.")
        ).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        let initialRowX = row.frame.minX
        row.swipeUp()
        XCTAssertEqual(row.frame.minX, initialRowX, accuracy: 3)
        row.swipeLeft()
        XCTAssertLessThan(row.frame.minX, initialRowX - 40)

        let deleteButton = app.buttons["today.deleteButton"]
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 5))
        deleteButton.tap()

        let confirmation = app.alerts["Delete Tick?"]
        XCTAssertTrue(confirmation.waitForExistence(timeout: 5))
        XCTAssertTrue(confirmation.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "Today Delete Tick")
        ).firstMatch.exists)
        confirmation.buttons["Cancel"].tap()
        XCTAssertTrue(confirmation.waitForNonExistence(timeout: 5))
        XCTAssertTrue(row.exists)

        row.swipeLeft()
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 5))
        deleteButton.tap()
        XCTAssertTrue(confirmation.waitForExistence(timeout: 5))
        confirmation.buttons["Delete Tick"].tap()

        XCTAssertTrue(row.waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["No time recorded yet today"].waitForExistence(timeout: 5))
    }

    func testTodayControlsTwoSpaceTicksIndependently() throws {
        continueAfterFailure = false
        let app = launchResetApp(fixture: .twoSpaces)

        let firstStart = app.buttons["today.playButton"]
        let secondStart = app.buttons["today.playButton.secondary"]
        let expandSecondTimer = app.buttons["today.secondTimer.expand"]
        XCTAssertTrue(firstStart.waitForExistence(timeout: 5))
        let isCollapsible = expandSecondTimer.exists
        if isCollapsible {
            XCTAssertFalse(secondStart.exists)
            expandSecondTimer.tap()
            let collapseSecondTimer = app.buttons["today.secondTimer.collapse"]
            XCTAssertTrue(collapseSecondTimer.waitForExistence(timeout: 5))
            collapseSecondTimer.tap()
            XCTAssertTrue(expandSecondTimer.waitForExistence(timeout: 5))
            expandSecondTimer.tap()
        }
        XCTAssertTrue(secondStart.waitForExistence(timeout: 5))
        firstStart.tap()
        secondStart.tap()

        let firstPause = app.buttons["today.pauseButton"]
        let secondPause = app.buttons["today.pauseButton.secondary"]
        XCTAssertTrue(firstPause.waitForExistence(timeout: 5))
        XCTAssertTrue(secondPause.waitForExistence(timeout: 5))
        firstPause.tap()
        XCTAssertTrue(app.buttons["today.playButton"].waitForExistence(timeout: 5))
        XCTAssertTrue(secondPause.exists)
        app.buttons["today.stopButton.secondary"].tap()
        if isCollapsible {
            XCTAssertTrue(expandSecondTimer.waitForExistence(timeout: 5))
        } else {
            XCTAssertTrue(secondStart.waitForExistence(timeout: 5))
        }
        XCTAssertTrue(app.buttons["today.playButton"].exists)
    }

    func testTodayTimerCardsCanBeReorderedWithoutChangingTheirTicks() throws {
        continueAfterFailure = false
        let app = launchResetApp(fixture: .twoSpaces)

        app.buttons["today.playButton"].tap()
        let expand = app.buttons["today.secondTimer.expand"]
        if expand.exists { expand.tap() }
        app.buttons["today.playButton.secondary"].tap()

        let firstCard = app.otherElements["today.timerCard"]
        let secondCard = app.otherElements["today.timerCard.secondary"]
        XCTAssertTrue(firstCard.waitForExistence(timeout: 5))
        XCTAssertTrue(secondCard.waitForExistence(timeout: 5))

        func isBefore(_ first: XCUIElement, _ second: XCUIElement) -> Bool {
            if abs(first.frame.midY - second.frame.midY) < 30 {
                return first.frame.minX < second.frame.minX
            }
            return first.frame.minY < second.frame.minY
        }

        XCTAssertTrue(isBefore(firstCard, secondCard))
        let dragHandle = app.descendants(matching: .any)["today.timerDragHandle"]
        XCTAssertTrue(dragHandle.waitForExistence(timeout: 5))
        let dragPoint = dragHandle.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let dropPoint = secondCard.coordinate(withNormalizedOffset: CGVector(dx: 0.87, dy: 0.12))
        dragPoint.press(forDuration: 0.8, thenDragTo: dropPoint)

        XCTAssertTrue(isBefore(secondCard, firstCard))
        app.buttons["today.pauseButton.secondary"].tap()
        XCTAssertTrue(app.buttons["today.playButton.secondary"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["today.pauseButton"].exists)

        app.terminate()
        app.launchArguments = ["-disableCloudSyncForUITests"]
        app.launch()
        XCTAssertTrue(firstCard.waitForExistence(timeout: 5))
        XCTAssertTrue(secondCard.waitForExistence(timeout: 5))
        XCTAssertTrue(isBefore(secondCard, firstCard))
    }

    func testCollapsedSecondTimerCanBeDraggedToTop() throws {
        continueAfterFailure = false
        let app = launchResetApp(fixture: .twoSpaces)

        let firstCard = app.otherElements["today.timerCard"]
        let secondCard = app.otherElements["today.timerCard.secondary"]
        XCTAssertTrue(firstCard.waitForExistence(timeout: 5))
        XCTAssertTrue(secondCard.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["today.secondTimer.expand"].exists)

        let dragHandle = app.descendants(matching: .any)["today.timerDragHandle.secondary"]
        XCTAssertTrue(dragHandle.waitForExistence(timeout: 5))
        let dragPoint = dragHandle.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let dropPoint = firstCard.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        dragPoint.press(
            forDuration: 1.0,
            thenDragTo: dropPoint,
            withVelocity: .slow,
            thenHoldForDuration: 0.5
        )

        XCTAssertLessThan(secondCard.frame.minY, firstCard.frame.minY)
        XCTAssertTrue(app.buttons["today.playButton.secondary"].exists)
        XCTAssertTrue(app.buttons["today.secondTimer.expand"].exists)
    }

    func testTodayTotalIncludesEverySpaceBeforeAndAfterStop() throws {
        continueAfterFailure = false
        let app = launchResetApp(fixture: .todayTotals)

        let expand = app.buttons["today.secondTimer.expand"]
        XCTAssertTrue(expand.waitForExistence(timeout: 5))
        expand.tap()
        let totals = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Today total "))
        XCTAssertEqual(totals.count, 2)
        XCTAssertEqual(totals.element(boundBy: 0).label, "Today total 30:00")
        XCTAssertEqual(totals.element(boundBy: 1).label, "Today total 30:00")

        app.buttons["today.playButton"].tap()
        let stop = app.buttons["today.stopButton"]
        XCTAssertTrue(stop.waitForExistence(timeout: 5))
        stop.tap()
        XCTAssertTrue(expand.waitForExistence(timeout: 5))
        expand.tap()
        XCTAssertEqual(totals.count, 2)
        XCTAssertEqual(totals.element(boundBy: 0).label, totals.element(boundBy: 1).label)
    }

    func testSummarySpaceOpensDetailedShareableReport() throws {
        continueAfterFailure = false
        let app = launchResetApp(fixture: .summaryReport)

        tab(named: "Summaries", in: app).tap()
        let spaces = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "summaries.space."))
        let space = spaces.matching(NSPredicate(format: "label == %@", "Client report")).firstMatch
        reveal(space, in: app)
        XCTAssertTrue(space.waitForExistence(timeout: 5))
        XCTAssertLessThan(space.frame.height, 160)
        let header = app.staticTexts["By Space"].firstMatch
        XCTAssertLessThan(space.frame.minY - header.frame.maxY, 90)
        space.tap()

        XCTAssertTrue(app.navigationBars["Space Report"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["spaceReport.total"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["spaceReport.total"].label, "30m")
        XCTAssertTrue(app.datePickers["spaceReport.fromDate"].exists)
        XCTAssertTrue(app.datePickers["spaceReport.throughDate"].exists)
        XCTAssertTrue(app.staticTexts["Implementation and testing"].firstMatch.exists)

        let reportScreenshot = XCTAttachment(screenshot: app.screenshot())
        reportScreenshot.name = "Space report"
        reportScreenshot.lifetime = .keepAlways
        add(reportScreenshot)

        let notesToggle = app.switches["spaceReport.includeNotes"]
        notesToggle.switches.firstMatch.tap()
        XCTAssertTrue(notesToggle.waitForValue("0", timeout: 5))

        let share = app.buttons["spaceReport.share"]
        XCTAssertTrue(share.isEnabled)
        share.tap()
        XCTAssertTrue(app.otherElements["ActivityListView"].waitForExistence(timeout: 10))
    }

    private func launchResetApp(fixture: UITestFixture? = nil) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "-resetDataForUITests",
            "-disableCloudSyncForUITests",
        ]
        if let fixture {
            app.launchArguments += ["-uiTestFixture", fixture.rawValue]
        }
        app.launch()
        return app
    }

    private func createProject(named projectName: String, in app: XCUIApplication) {
        let projectsTab = tab(named: "Spaces", in: app)
        XCTAssertTrue(projectsTab.waitForExistence(timeout: 5))
        projectsTab.tap()

        let addProjectButton = app.buttons["projects.addProjectButton"]
        XCTAssertTrue(addProjectButton.waitForExistence(timeout: 5))
        addProjectButton.tap()

        let projectNameField = app.textFields["addProject.nameField"]
        XCTAssertTrue(projectNameField.waitForExistence(timeout: 5))
        projectNameField.tap()
        projectNameField.typeText(projectName)

        let saveProjectButton = app.buttons["addProject.saveButton"]
        XCTAssertTrue(saveProjectButton.waitForExistence(timeout: 5))
        saveProjectButton.tap()

        XCTAssertTrue(app.staticTexts[projectName].waitForExistence(timeout: 5))
    }

    private func addManualSession(titled sessionTitle: String, notes: String = "", in app: XCUIApplication) {
        let todayTab = tab(named: "Today", in: app)
        XCTAssertTrue(todayTab.waitForExistence(timeout: 5))
        todayTab.tap()

        let addTimeButton = app.buttons["today.addTimeButton"]
        XCTAssertTrue(addTimeButton.waitForExistence(timeout: 5))
        addTimeButton.tap()

        let manualTitleField = app.textFields["manualTime.titleField"]
        XCTAssertTrue(manualTitleField.waitForExistence(timeout: 5))
        manualTitleField.tap()
        manualTitleField.typeText(sessionTitle)

        if !notes.isEmpty {
            let notesField = app.textFields["manualTime.notesField"]
            notesField.tap()
            notesField.typeText(notes)
        }

        let manualSaveButton = app.buttons["manualTime.saveButton"]
        XCTAssertTrue(manualSaveButton.waitForExistence(timeout: 5))
        let hideKeyboard = app.buttons["Hide keyboard"]
        if hideKeyboard.exists {
            hideKeyboard.tap()
            XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 5))
        }
        XCTAssertTrue(manualSaveButton.waitUntilHittable(timeout: 5))
        manualSaveButton.tap()

        XCTAssertTrue(manualTitleField.waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts[sessionTitle].waitForExistence(timeout: 5))
    }

    private func tab(named title: String, in app: XCUIApplication) -> XCUIElement {
        // iPad's floating tabs are exposed as cells rather than a TabBar.
        app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", title)).firstMatch
    }

    private func reveal(_ element: XCUIElement, in app: XCUIApplication, maxSwipes: Int = 6) {
        for _ in 0..<maxSwipes where !element.exists {
            app.swipeUp()
        }
    }
}

private enum UITestFixture: String {
    case capture
    case manualEditing
    case timingEditing
    case projectDeletion
    case todayDeletion
    case twoSpaces
    case todayTotals
    case summaryReport
}

private extension XCUIElement {
    func waitForValue(_ expectedValue: String, timeout: TimeInterval) -> Bool {
        let predicate = NSPredicate(format: "value == %@", expectedValue)
        return XCTWaiter.wait(
            for: [XCTNSPredicateExpectation(predicate: predicate, object: self)],
            timeout: timeout
        ) == .completed
    }

    func waitUntilEnabled(timeout: TimeInterval) -> Bool {
        let predicate = NSPredicate(format: "isEnabled == true")
        return XCTWaiter.wait(
            for: [XCTNSPredicateExpectation(predicate: predicate, object: self)],
            timeout: timeout
        ) == .completed
    }

    func waitUntilHittable(timeout: TimeInterval) -> Bool {
        let predicate = NSPredicate(format: "isHittable == true")
        return XCTWaiter.wait(
            for: [XCTNSPredicateExpectation(predicate: predicate, object: self)],
            timeout: timeout
        ) == .completed
    }
}

private extension XCUIElement {
    func clearAndEnterText(_ text: String) {
        guard let currentValue = value as? String else {
            tap()
            typeText(text)
            return
        }

        tap()
        let deleteString = String(repeating: XCUIKeyboardKey.delete.rawValue, count: currentValue.count)
        typeText(deleteString + text)
    }
}

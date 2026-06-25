import XCTest

final class TickUITests: XCTestCase {
    func testPrimaryTabsExist() throws {
        let app = XCUIApplication()
        app.launch()

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
        XCTAssertTrue(stopButton.waitUntilEnabled(timeout: 5))
        stopButton.tap()

        XCTAssertTrue(app.buttons["Start Tick"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["today.sessionsHeader"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["1 Tick"].waitForExistence(timeout: 5))
    }

    func testSpaceAndSessionPersistAfterRelaunch() throws {
        let app = launchResetApp()

        let projectName = "Persistent UI Project"
        let sessionTitle = "Persistent UI Session"

        createProject(named: projectName, in: app)
        addManualSession(titled: sessionTitle, in: app)

        app.terminate()
        app.launchArguments = []
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

    func testSelectedTabSurvivesAppReactivationAndRelaunch() throws {
        let app = launchResetApp()
        let tabBar = app.tabBars.firstMatch

        let todayTab = tabBar.buttons["Today"]
        XCTAssertTrue(todayTab.waitForExistence(timeout: 5))
        XCTAssertTrue(todayTab.isSelected)

        let autoTicksTab = tabBar.buttons["Auto Ticks"]
        XCTAssertTrue(autoTicksTab.waitForExistence(timeout: 5))
        autoTicksTab.tap()
        XCTAssertTrue(autoTicksTab.isSelected)

        app.terminate()
        app.launchArguments = []
        app.launch()

        XCTAssertTrue(autoTicksTab.waitForExistence(timeout: 5))
        XCTAssertTrue(autoTicksTab.isSelected)
        XCTAssertFalse(todayTab.isSelected)

        todayTab.tap()
        XCTAssertTrue(todayTab.isSelected)

        XCUIDevice.shared.press(.home)
        app.activate()

        XCTAssertTrue(todayTab.waitForExistence(timeout: 5))
        XCTAssertTrue(todayTab.isSelected)
        XCTAssertFalse(autoTicksTab.isSelected)

        app.terminate()
        app.launch()

        XCTAssertTrue(todayTab.waitForExistence(timeout: 5))
        XCTAssertTrue(todayTab.isSelected)
        XCTAssertFalse(autoTicksTab.isSelected)
    }

    func testManualTimeSessionCanBeEditedFromSessionDetail() throws {
        let app = XCUIApplication()
        app.launchArguments.append("-resetDataForUITests")
        app.launch()

        let projectName = "Manual UI Project"
        let initialSessionTitle = "Manual UI Session"
        let editedSessionTitle = "Edited Manual UI Session"
        let tabBar = app.tabBars.firstMatch

        let projectsTab = tabBar.buttons["Spaces"]
        XCTAssertTrue(projectsTab.waitForExistence(timeout: 5))
        projectsTab.tap()

        let addProjectButton = app.buttons["projects.addProjectButton"]
        XCTAssertTrue(addProjectButton.waitForExistence(timeout: 5))
        addProjectButton.tap()

        let projectNameField = app.textFields["addProject.nameField"]
        XCTAssertTrue(projectNameField.waitForExistence(timeout: 5))
        XCTAssertTrue(projectNameField.waitUntilHittable(timeout: 5))
        projectNameField.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        projectNameField.typeText(projectName)

        let saveProjectButton = app.buttons["addProject.saveButton"]
        XCTAssertTrue(saveProjectButton.waitForExistence(timeout: 5))
        saveProjectButton.tap()

        XCTAssertTrue(app.staticTexts[projectName].waitForExistence(timeout: 5))

        let todayTab = tabBar.buttons["Today"]
        XCTAssertTrue(todayTab.waitForExistence(timeout: 5))
        todayTab.tap()

        let addTimeButton = app.buttons["today.addTimeButton"]
        XCTAssertTrue(addTimeButton.waitForExistence(timeout: 5))
        addTimeButton.tap()

        let manualTitleField = app.textFields["manualTime.titleField"]
        XCTAssertTrue(manualTitleField.waitForExistence(timeout: 5))
        manualTitleField.tap()
        manualTitleField.typeText(initialSessionTitle)

        let manualNotesField = app.textFields["manualTime.notesField"]
        XCTAssertTrue(manualNotesField.waitForExistence(timeout: 5))
        manualNotesField.tap()
        manualNotesField.typeText("Logged from UI test")

        let manualSaveButton = app.buttons["manualTime.saveButton"]
        XCTAssertTrue(manualSaveButton.waitForExistence(timeout: 5))
        manualSaveButton.tap()

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

    func testProjectDetailSessionCanBeDeleted() throws {
        let app = launchResetApp()

        let projectName = "Delete UI Project"
        let sessionTitle = "Delete UI Session"
        let tabBar = app.tabBars.firstMatch

        createProject(named: projectName, in: app)

        let todayTab = tabBar.buttons["Today"]
        XCTAssertTrue(todayTab.waitForExistence(timeout: 5))
        todayTab.tap()

        let addTimeButton = app.buttons["today.addTimeButton"]
        XCTAssertTrue(addTimeButton.waitForExistence(timeout: 5))
        addTimeButton.tap()

        let manualTitleField = app.textFields["manualTime.titleField"]
        XCTAssertTrue(manualTitleField.waitForExistence(timeout: 5))
        manualTitleField.tap()
        manualTitleField.typeText(sessionTitle)

        let manualSaveButton = app.buttons["manualTime.saveButton"]
        XCTAssertTrue(manualSaveButton.waitForExistence(timeout: 5))
        manualSaveButton.tap()

        XCTAssertFalse(manualTitleField.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["today.sessionsHeader"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts[sessionTitle].waitForExistence(timeout: 5))

        let projectsTab = tabBar.buttons["Spaces"]
        XCTAssertTrue(projectsTab.waitForExistence(timeout: 5))
        projectsTab.tap()
        XCTAssertTrue(app.staticTexts[projectName].waitForExistence(timeout: 5))
        app.staticTexts[projectName].tap()

        let projectSessionRowText = app.staticTexts[sessionTitle]
        XCTAssertTrue(projectSessionRowText.waitForExistence(timeout: 5))

        let projectSessionRow = app.cells.containing(.staticText, identifier: sessionTitle).firstMatch
        XCTAssertTrue(projectSessionRow.waitForExistence(timeout: 5))
        projectSessionRow.swipeLeft()
        let deleteButton = app.buttons["Delete"]
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 5))
        deleteButton.tap()

        XCTAssertFalse(projectSessionRowText.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["No Ticks yet"].waitForExistence(timeout: 5))
    }

    private func launchResetApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments.append("-resetDataForUITests")
        app.launch()
        return app
    }

    private func createProject(named projectName: String, in app: XCUIApplication) {
        let projectsTab = app.tabBars.firstMatch.buttons["Spaces"]
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

    private func addManualSession(titled sessionTitle: String, in app: XCUIApplication) {
        let todayTab = app.tabBars.firstMatch.buttons["Today"]
        XCTAssertTrue(todayTab.waitForExistence(timeout: 5))
        todayTab.tap()

        let addTimeButton = app.buttons["today.addTimeButton"]
        XCTAssertTrue(addTimeButton.waitForExistence(timeout: 5))
        addTimeButton.tap()

        let manualTitleField = app.textFields["manualTime.titleField"]
        XCTAssertTrue(manualTitleField.waitForExistence(timeout: 5))
        manualTitleField.tap()
        manualTitleField.typeText(sessionTitle)

        let manualSaveButton = app.buttons["manualTime.saveButton"]
        XCTAssertTrue(manualSaveButton.waitForExistence(timeout: 5))
        manualSaveButton.tap()

        XCTAssertFalse(manualTitleField.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts[sessionTitle].waitForExistence(timeout: 5))
    }
}

private extension XCUIElement {
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

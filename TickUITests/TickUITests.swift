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
        let app = XCUIApplication()
        app.launchArguments.append("-resetDataForUITests")
        app.launch()

        let projectName = "UITest Project"
        let tabBar = app.tabBars.firstMatch

        let projectsTab = tabBar.buttons["Spaces"]
        XCTAssertTrue(projectsTab.waitForExistence(timeout: 5))
        projectsTab.tap()

        let addProjectButton = app.buttons["projects.addProjectButton"]
        XCTAssertTrue(addProjectButton.waitForExistence(timeout: 5))
        addProjectButton.tap()

        let nameField = app.textFields["addProject.nameField"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        nameField.tap()
        nameField.typeText(projectName)

        let saveProjectButton = app.buttons["addProject.saveButton"]
        XCTAssertTrue(saveProjectButton.waitForExistence(timeout: 5))
        saveProjectButton.tap()

        XCTAssertTrue(app.staticTexts[projectName].waitForExistence(timeout: 5))

        let todayTab = tabBar.buttons["Today"]
        XCTAssertTrue(todayTab.waitForExistence(timeout: 5))
        todayTab.tap()

        let startStopButton = app.buttons["today.startStopButton"]
        XCTAssertTrue(startStopButton.waitForExistence(timeout: 5))
        XCTAssertEqual(startStopButton.label, "Start Tick")
        startStopButton.tap()

        XCTAssertTrue(app.buttons["Stop Tick"].waitForExistence(timeout: 5))
        app.buttons["Stop Tick"].tap()

        XCTAssertTrue(app.buttons["Start Tick"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["today.sessionsHeader"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts[projectName].waitForExistence(timeout: 5))
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
        projectNameField.tap()
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
        let app = XCUIApplication()
        app.launchArguments.append("-resetDataForUITests")
        app.launch()

        let projectName = "Delete UI Project"
        let sessionTitle = "Delete UI Session"
        let tabBar = app.tabBars.firstMatch

        let projectsTab = tabBar.buttons["Spaces"]
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

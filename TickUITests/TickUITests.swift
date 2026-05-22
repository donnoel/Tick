import XCTest

final class TickUITests: XCTestCase {
    func testPrimaryTabsExist() throws {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.tabBars.buttons["Today"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.tabBars.buttons["Projects"].exists)
        XCTAssertTrue(app.tabBars.buttons["Auto Ticks"].exists)
        XCTAssertTrue(app.tabBars.buttons["Summaries"].exists)
    }
}

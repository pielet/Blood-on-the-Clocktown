import XCTest

final class blood_on_the_clocktowerUITestsLaunchTests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunch() throws {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(
            app.staticTexts["template-trouble-brewing"].firstMatch.waitForExistence(timeout: 15),
            "App should finish launching into the template selection screen"
        )
    }
}

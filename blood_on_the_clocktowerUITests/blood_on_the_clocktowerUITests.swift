import XCTest

final class BloodOnTheClockTowerUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    @MainActor
    func testTemplatesAreListed() throws {
        XCTAssertTrue(
            templateElement("trouble-brewing").waitForExistence(timeout: 15),
            "Trouble Brewing template should appear on launch"
        )
        XCTAssertTrue(templateElement("bad-moon-rising").exists)
        XCTAssertTrue(templateElement("sects-and-violets").exists)
    }

    @MainActor
    func testTroubleBrewingReachesAssignment() throws {
        let templateButton = templateElement("trouble-brewing")
        XCTAssertTrue(templateButton.waitForExistence(timeout: 15))
        templateButton.tap()

        let drawButton = app.buttons["setup-drawRoles"]
        XCTAssertTrue(drawButton.waitForExistence(timeout: 5))

        let stepper = app.steppers["setup-stepper"]
        XCTAssertTrue(stepper.waitForExistence(timeout: 3))
        stepperButton(in: stepper, direction: "Decrement").tap()
        stepperButton(in: stepper, direction: "Decrement").tap()

        scrollTo(drawButton)
        drawButton.tap()

        handleDrunkSelectionIfNeeded()

        let assignButton = app.buttons["setup-assignRoles"]
        XCTAssertTrue(assignButton.waitForExistence(timeout: 5))
        scrollTo(assignButton)
        assignButton.tap()

        XCTAssertTrue(
            app.buttons["assignment-nightFalls"].waitForExistence(timeout: 5),
            "Assignment view should surface the Night Falls button"
        )
        XCTAssertTrue(app.buttons["assignment-card-0"].exists)
    }

    // MARK: - Helpers

    /// Template rows are SwiftUI VStacks with `.onTapGesture`; SwiftUI propagates
    /// the identifier down to child static text elements. Tapping the label routes
    /// the hit test up to the VStack's gesture.
    private func templateElement(_ templateId: String) -> XCUIElement {
        app.staticTexts["template-\(templateId)"].firstMatch
    }

    private func scrollTo(_ element: XCUIElement, maxAttempts: Int = 3) {
        guard element.exists else { return }
        if element.isHittable { return }
        for _ in 0..<maxAttempts {
            app.swipeUp()
            if element.isHittable { return }
        }
    }

    private func stepperButton(in stepper: XCUIElement, direction: String) -> XCUIElement {
        let prefixed = stepper.buttons["setup-stepper-\(direction)"]
        return prefixed.exists ? prefixed : stepper.buttons[direction]
    }

    private func handleDrunkSelectionIfNeeded() {
        _ = app.buttons["setup-assignRoles"].waitForExistence(timeout: 2)
        for element in app.buttons.allElementsBoundByIndex where element.identifier.hasPrefix("setup-drunkChoice-") {
            scrollTo(element)
            element.tap()
            _ = app.buttons["setup-assignRoles"].waitForExistence(timeout: 2)
            return
        }
    }
}

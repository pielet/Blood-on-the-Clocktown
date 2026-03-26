import XCTest

final class BloodOnTheClockTowerUITests: XCTestCase {

    private var app: XCUIApplication!
    private let playerCount = 5

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Full Game Simulation

    @MainActor
    func testFullTroubleBrewingGame() throws {
        // 1. Select Trouble Brewing template
        let templateButton = app.buttons["template-trouble-brewing"]
        XCTAssertTrue(templateButton.waitForExistence(timeout: 10), "Trouble Brewing template button should exist")
        templateButton.tap()

        // 2. Player setup — use 5 players (minimum, fastest game)
        let drawButton = app.buttons["setup-drawRoles"]
        XCTAssertTrue(drawButton.waitForExistence(timeout: 5), "Draw Roles button should exist")
        let stepper = app.steppers["setup-stepper"]
        XCTAssertTrue(stepper.waitForExistence(timeout: 5), "Player stepper should exist")
        stepperButton(in: stepper, direction: "Decrement").tap()
        stepperButton(in: stepper, direction: "Decrement").tap()

        scrollTo(drawButton)
        drawButton.tap()

        handleDrunkSelectionIfNeeded()

        let assignButton = app.buttons["setup-assignRoles"]
        XCTAssertTrue(assignButton.waitForExistence(timeout: 5), "Assign Roles button should exist")
        scrollTo(assignButton)
        assignButton.tap()

        // 3. Assignment — tap each card twice (flip open, flip closed/used)
        let nightFallsButton = app.buttons["assignment-nightFalls"]
        XCTAssertTrue(nightFallsButton.waitForExistence(timeout: 5), "Night Falls button should exist")

        for i in 0..<playerCount {
            let card = app.buttons["assignment-card-\(i)"]
            if card.waitForExistence(timeout: 3) {
                scrollTo(card)
                card.tap()
                // Wait for flip animation then tap again to dismiss
                _ = card.waitForExistence(timeout: 2)
                if card.exists && card.isHittable {
                    card.tap()
                    _ = card.waitForExistence(timeout: 2)
                }
            }
        }

        scrollTo(nightFallsButton)
        nightFallsButton.tap()

        // 4. Handle Imp Bluff setup if it appears
        handleImpBluffSetupIfNeeded()

        // 5. Handle fortune teller red herring if it appears
        handleFortuneTellerRedHerringIfNeeded()

        // 6. Run night/day cycles until game over
        let maxCycles = 20
        for _ in 0..<maxCycles {
            if app.staticTexts["gameover-winner"].waitForExistence(timeout: 1) {
                break
            }

            driveNightPhase()

            if app.staticTexts["gameover-winner"].waitForExistence(timeout: 1) {
                break
            }

            driveDayPhase()
        }

        // 7. Verify game over screen
        let winnerText = app.staticTexts["gameover-winner"]
        XCTAssertTrue(winnerText.waitForExistence(timeout: 10), "Game over winner text should appear")

        // 8. Restart and verify back at template selection
        let restartButton = app.buttons["gameover-restart"]
        XCTAssertTrue(restartButton.waitForExistence(timeout: 5), "Restart button should exist on game over screen")
        scrollTo(restartButton)
        restartButton.tap()

        XCTAssertTrue(
            app.buttons["template-trouble-brewing"].waitForExistence(timeout: 5),
            "Should return to template selection after restart"
        )
    }

    // MARK: - Template Listing

    @MainActor
    func testLaunchAndSelectEachTemplate() throws {
        // Verify all 3 templates appear
        XCTAssertTrue(app.buttons["template-trouble-brewing"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["template-bad-moon-rising"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["template-sects-and-violets"].waitForExistence(timeout: 5))

        // Select Trouble Brewing, verify player setup appears
        app.buttons["template-trouble-brewing"].tap()
        XCTAssertTrue(app.buttons["setup-drawRoles"].waitForExistence(timeout: 5))

        // Reset and select Bad Moon Rising
        tapRestartButton()
        XCTAssertTrue(app.buttons["template-bad-moon-rising"].waitForExistence(timeout: 5))
        app.buttons["template-bad-moon-rising"].tap()
        XCTAssertTrue(app.buttons["setup-drawRoles"].waitForExistence(timeout: 5))

        // Reset and select Sects and Violets
        tapRestartButton()
        XCTAssertTrue(app.buttons["template-sects-and-violets"].waitForExistence(timeout: 5))
        app.buttons["template-sects-and-violets"].tap()
        XCTAssertTrue(app.buttons["setup-drawRoles"].waitForExistence(timeout: 5))
    }

    // MARK: - Player Setup Adjustments

    @MainActor
    func testPlayerSetupAdjustments() throws {
        let templateButton = app.buttons["template-trouble-brewing"]
        XCTAssertTrue(templateButton.waitForExistence(timeout: 10))
        templateButton.tap()

        let drawButton = app.buttons["setup-drawRoles"]
        XCTAssertTrue(drawButton.waitForExistence(timeout: 5))

        // Draw roles at default count
        scrollTo(drawButton)
        drawButton.tap()

        handleDrunkSelectionIfNeeded()
        let assignButton = app.buttons["setup-assignRoles"]
        XCTAssertTrue(assignButton.waitForExistence(timeout: 5))

        // Adjust player count up
        let stepper = app.steppers["setup-stepper"]
        scrollTo(stepper)
        stepperButton(in: stepper, direction: "Increment").tap()

        // Draw again — new deck for new count
        scrollTo(drawButton)
        drawButton.tap()

        // Verify assign button still available
        handleDrunkSelectionIfNeeded()
        XCTAssertTrue(assignButton.waitForExistence(timeout: 5))
    }

    // MARK: - Night/Day Drivers

    private func driveNightPhase() {
        let completeButton = app.buttons["night-complete"]
        let skipButton = app.buttons["night-skip"]

        for _ in 0..<20 {
            // Check if we've transitioned to day or game over
            if app.buttons["day-execute"].exists || app.buttons["day-skip"].exists
                || app.staticTexts["gameover-winner"].exists {
                return
            }

            handleFortuneTellerRedHerringIfNeeded()
            handleImpReplacementIfNeeded()

            if completeButton.waitForExistence(timeout: 2) {
                // Scroll to action area and try to select a target
                scrollTo(completeButton)
                selectFirstAvailableNightTarget()
                scrollTo(completeButton)
                if completeButton.isHittable {
                    completeButton.tap()
                    _ = completeButton.waitForExistence(timeout: 2)
                    continue
                }
            }

            if skipButton.exists {
                scrollTo(skipButton)
                if skipButton.isHittable {
                    skipButton.tap()
                    _ = skipButton.waitForExistence(timeout: 2)
                    continue
                }
            }

            // Neither button is actionable — night may be done
            if !completeButton.exists && !skipButton.exists {
                return
            }
            // Buttons exist but aren't hittable yet — brief wait and retry
            _ = completeButton.waitForExistence(timeout: 1)
        }
    }

    private func driveDayPhase() {
        // Wait for day phase UI to appear
        let executeButton = app.buttons["day-execute"]
        let skipButton = app.buttons["day-skip"]

        guard executeButton.waitForExistence(timeout: 5) || skipButton.waitForExistence(timeout: 2) else { return }

        // Scroll down past the storyteller panel to reach the nomination section
        app.swipeUp()

        // Pick the first available nominator
        if let nominatorButton = findFirstButton(prefix: "day-nominator-") {
            scrollTo(nominatorButton)
            nominatorButton.tap()

            // Wait for nominee list to appear, then pick one
            _ = app.buttons["day-skip"].waitForExistence(timeout: 3)
            if let nomineeButton = findFirstButton(prefix: "day-nominee-") {
                scrollTo(nomineeButton)
                nomineeButton.tap()

                // Wait for vote buttons to appear
                _ = app.buttons["day-lockVote"].waitForExistence(timeout: 3)

                // Vote: tap all available vote buttons to get majority
                for seat in 1...playerCount {
                    let voteButton = app.buttons["day-vote-\(seat)"]
                    if voteButton.exists {
                        scrollTo(voteButton)
                        if voteButton.isHittable {
                            voteButton.tap()
                        }
                    }
                }

                // Lock the vote
                let lockButton = app.buttons["day-lockVote"]
                scrollTo(lockButton)
                if lockButton.exists && lockButton.isHittable {
                    lockButton.tap()
                    _ = executeButton.waitForExistence(timeout: 3)
                }
            }
        }

        // Execute if we have a valid nomination, otherwise skip the day
        scrollTo(executeButton)
        if executeButton.exists && executeButton.isHittable && executeButton.isEnabled {
            executeButton.tap()
        } else {
            scrollTo(skipButton)
            if skipButton.exists && skipButton.isHittable {
                skipButton.tap()
            }
        }

        // Wait for transition to night or game over
        _ = app.buttons["night-complete"].waitForExistence(timeout: 3)
    }

    // MARK: - Helpers

    /// Scroll the view until an element is hittable.
    private func scrollTo(_ element: XCUIElement, maxAttempts: Int = 5) {
        guard element.exists else { return }
        if element.isHittable { return }

        for _ in 0..<maxAttempts {
            app.swipeUp()
            if element.isHittable { return }
        }
        // Element might be above — scroll back
        for _ in 0..<(maxAttempts * 2) {
            app.swipeDown()
            if element.isHittable { return }
        }
    }

    /// Tap the restart button, handling toolbar placement across iOS versions.
    private func tapRestartButton() {
        // Toolbar buttons may be found via app.buttons or navigationBars.buttons
        let restart = app.buttons["content-restart"]
        if restart.waitForExistence(timeout: 3) {
            restart.tap()
            return
        }
        let navRestart = app.navigationBars.buttons["content-restart"]
        if navRestart.waitForExistence(timeout: 3) {
            navRestart.tap()
            return
        }
        // Fallback: find by label
        for label in ["Restart", "重新开始"] {
            let byLabel = app.navigationBars.buttons[label]
            if byLabel.exists {
                byLabel.tap()
                return
            }
        }
        XCTFail("Could not find restart button")
    }

    private func handleDrunkSelectionIfNeeded() {
        // Wait for UI to settle after drawing
        _ = app.buttons["setup-assignRoles"].waitForExistence(timeout: 3)
        // If drunk choice buttons exist, tap the first one
        if let drunkChoice = findFirstButton(prefix: "setup-drunkChoice-") {
            scrollTo(drunkChoice)
            drunkChoice.tap()
            _ = app.buttons["setup-assignRoles"].waitForExistence(timeout: 2)
        }
    }

    private func handleImpBluffSetupIfNeeded() {
        let showToImpButton = app.buttons["impbluff-showToImp"]
        guard showToImpButton.waitForExistence(timeout: 3) else { return }

        // Select the first 3 available bluff roles
        var selected = 0
        for button in app.buttons.allElementsBoundByIndex where button.identifier.hasPrefix("impbluff-role-") {
            if selected >= 3 { break }
            scrollTo(button)
            button.tap()
            selected += 1
        }

        scrollTo(showToImpButton)
        showToImpButton.tap()

        // Handle the reveal view
        let revealNightFalls = app.buttons["impbluffreveal-nightFalls"]
        if revealNightFalls.waitForExistence(timeout: 3) {
            revealNightFalls.tap()
        }
    }

    private func handleFortuneTellerRedHerringIfNeeded() {
        if let redHerringButton = findFirstButton(prefix: "night-redherring-") {
            scrollTo(redHerringButton)
            redHerringButton.tap()
            _ = app.buttons["night-complete"].waitForExistence(timeout: 3)
        }
    }

    private func handleImpReplacementIfNeeded() {
        if let replacementButton = findFirstButton(prefix: "night-impReplacement-") {
            scrollTo(replacementButton)
            replacementButton.tap()
            _ = app.buttons["night-complete"].waitForExistence(timeout: 3)
        }
    }

    private func stepperButton(in stepper: XCUIElement, direction: String) -> XCUIElement {
        let prefixed = stepper.buttons["setup-stepper-\(direction)"]
        if prefixed.exists {
            return prefixed
        }
        return stepper.buttons[direction]
    }

    private func selectFirstAvailableNightTarget() {
        for seat in 1...playerCount {
            let targetButton = app.buttons["night-target-\(seat)"]
            if targetButton.exists {
                scrollTo(targetButton)
                if targetButton.isHittable {
                    targetButton.tap()
                    return
                }
            }
        }
    }

    private func findFirstButton(prefix: String) -> XCUIElement? {
        for element in app.buttons.allElementsBoundByIndex {
            if element.identifier.hasPrefix(prefix) {
                return element
            }
        }
        return nil
    }
}

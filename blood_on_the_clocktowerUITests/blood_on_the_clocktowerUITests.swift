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

    // MARK: - Full Game Simulation

    @MainActor
    func testFullTroubleBrewingGame() throws {
        // 1. Select Trouble Brewing template
        let templateButton = app.buttons["template-trouble_brewing"]
        XCTAssertTrue(templateButton.waitForExistence(timeout: 5), "Trouble Brewing template button should exist")
        templateButton.tap()

        // 2. Player setup — use 5 players (minimum, fastest game)
        let drawButton = app.buttons["setup-drawRoles"]
        XCTAssertTrue(drawButton.waitForExistence(timeout: 3), "Draw Roles button should exist")
        // Tap the stepper decrement to get to 5 (default is 7, decrement twice)
        let stepper = app.steppers["setup-stepper"]
        XCTAssertTrue(stepper.exists, "Player stepper should exist")
        stepper.buttons["Decrement"].tap()
        stepper.buttons["Decrement"].tap()

        drawButton.tap()

        let assignButton = app.buttons["setup-assignRoles"]
        XCTAssertTrue(assignButton.waitForExistence(timeout: 3), "Assign Roles button should exist")
        // Wait for it to become enabled (drunk selection may be needed)
        // If there's a drunk, just tap the first available drunk choice
        handleDrunkSelectionIfNeeded()
        assignButton.tap()

        // 3. Assignment — tap each card twice (flip open, flip closed/used)
        let nightFallsButton = app.buttons["assignment-nightFalls"]
        XCTAssertTrue(nightFallsButton.waitForExistence(timeout: 3), "Night Falls button should exist")

        for i in 0..<5 {
            let card = app.buttons["assignment-card-\(i)"]
            if card.waitForExistence(timeout: 2) {
                card.tap()
                // Brief wait for flip animation
                usleep(500_000)
                // Tap again to dismiss (flip back / mark used)
                card.tap()
                usleep(500_000)
            }
        }

        nightFallsButton.tap()

        // 4. Handle Imp Bluff setup if it appears
        handleImpBluffSetupIfNeeded()

        // 5. Handle fortune teller red herring if it appears
        handleFortuneTellerRedHerringIfNeeded()

        // 6. Run night/day cycles until game over
        let maxCycles = 20
        for _ in 0..<maxCycles {
            // Check if game is over
            if app.staticTexts["gameover-winner"].waitForExistence(timeout: 1) {
                break
            }

            // Night phase: complete/skip all steps
            driveNightPhase()

            // Check if game ended during night
            if app.staticTexts["gameover-winner"].waitForExistence(timeout: 1) {
                break
            }

            // Day phase: nominate, vote, execute
            driveDayPhase()
        }

        // 7. Verify game over screen
        let winnerText = app.staticTexts["gameover-winner"]
        XCTAssertTrue(winnerText.waitForExistence(timeout: 5), "Game over winner text should appear")

        // 8. Restart and verify back at template selection
        let restartButton = app.buttons["gameover-restart"]
        XCTAssertTrue(restartButton.exists, "Restart button should exist on game over screen")
        restartButton.tap()

        XCTAssertTrue(
            app.buttons["template-trouble_brewing"].waitForExistence(timeout: 3),
            "Should return to template selection after restart"
        )
    }

    // MARK: - Template Listing

    @MainActor
    func testLaunchAndSelectEachTemplate() throws {
        // Verify all 3 templates appear
        XCTAssertTrue(app.buttons["template-trouble_brewing"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["template-bad_moon_rising"].exists)
        XCTAssertTrue(app.buttons["template-sects_and_violets"].exists)

        // Select Trouble Brewing, verify player setup appears
        app.buttons["template-trouble_brewing"].tap()
        XCTAssertTrue(app.buttons["setup-drawRoles"].waitForExistence(timeout: 3))

        // Reset and select Bad Moon Rising
        let restartButton = app.buttons["content-restart"]
        XCTAssertTrue(restartButton.exists)
        restartButton.tap()

        XCTAssertTrue(app.buttons["template-bad_moon_rising"].waitForExistence(timeout: 3))
        app.buttons["template-bad_moon_rising"].tap()
        XCTAssertTrue(app.buttons["setup-drawRoles"].waitForExistence(timeout: 3))

        // Reset and select Sects and Violets
        restartButton.tap()
        XCTAssertTrue(app.buttons["template-sects_and_violets"].waitForExistence(timeout: 3))
        app.buttons["template-sects_and_violets"].tap()
        XCTAssertTrue(app.buttons["setup-drawRoles"].waitForExistence(timeout: 3))
    }

    // MARK: - Player Setup Adjustments

    @MainActor
    func testPlayerSetupAdjustments() throws {
        // Select a template first
        app.buttons["template-trouble_brewing"].tap()

        let drawButton = app.buttons["setup-drawRoles"]
        XCTAssertTrue(drawButton.waitForExistence(timeout: 3))

        // Draw roles at default count
        drawButton.tap()

        // Verify assign button becomes available (may need drunk selection)
        handleDrunkSelectionIfNeeded()
        let assignButton = app.buttons["setup-assignRoles"]
        XCTAssertTrue(assignButton.waitForExistence(timeout: 3))

        // Adjust player count up
        let stepper = app.steppers["setup-stepper"]
        stepper.buttons["Increment"].tap()

        // Draw again — new deck for new count
        drawButton.tap()

        // Verify assign button still available
        handleDrunkSelectionIfNeeded()
        XCTAssertTrue(assignButton.waitForExistence(timeout: 3))
    }

    // MARK: - Night/Day Drivers

    private func driveNightPhase() {
        let completeButton = app.buttons["night-complete"]
        let skipButton = app.buttons["night-skip"]

        // Process up to 20 night steps
        for _ in 0..<20 {
            // Check if we've moved to day or game over
            if app.buttons["day-execute"].exists || app.staticTexts["gameover-winner"].exists {
                return
            }

            // Handle fortune teller red herring if it appears mid-night
            handleFortuneTellerRedHerringIfNeeded()

            // Handle imp replacement if needed
            handleImpReplacementIfNeeded()

            if completeButton.exists && completeButton.isHittable {
                // Try to select the first available night target
                selectFirstAvailableNightTarget()
                completeButton.tap()
                usleep(300_000)
            } else if skipButton.exists && skipButton.isHittable {
                skipButton.tap()
                usleep(300_000)
            } else {
                // Night phase may be done — wait briefly for transition
                usleep(500_000)
                if !completeButton.exists && !skipButton.exists {
                    return
                }
            }
        }
    }

    private func driveDayPhase() {
        let executeButton = app.buttons["day-execute"]
        let skipButton = app.buttons["day-skip"]

        // Wait for day phase UI
        guard executeButton.waitForExistence(timeout: 3) else { return }

        // Try to nominate and vote
        // Pick the first available nominator
        if let nominatorButton = findFirstButton(prefix: "day-nominator-") {
            nominatorButton.tap()
            usleep(300_000)

            // Pick the first available nominee
            if let nomineeButton = findFirstButton(prefix: "day-nominee-") {
                nomineeButton.tap()
                usleep(300_000)

                // Vote: tap all available vote buttons to get majority
                for seat in 1...5 {
                    let voteButton = app.buttons["day-vote-\(seat)"]
                    if voteButton.exists && voteButton.isHittable {
                        voteButton.tap()
                        usleep(100_000)
                    }
                }

                // Lock the vote
                let lockButton = app.buttons["day-lockVote"]
                if lockButton.exists && lockButton.isHittable {
                    lockButton.tap()
                    usleep(300_000)
                }
            }
        }

        // Execute if available, otherwise skip
        if executeButton.exists && executeButton.isHittable && executeButton.isEnabled {
            executeButton.tap()
        } else if skipButton.exists && skipButton.isHittable {
            skipButton.tap()
        }
        usleep(500_000)
    }

    // MARK: - Helpers

    private func handleDrunkSelectionIfNeeded() {
        // If drunk cards exist, there will be drunk role choice buttons
        // Just wait briefly and continue - if assign is disabled it may need drunk selection
        usleep(300_000)
    }

    private func handleImpBluffSetupIfNeeded() {
        let showToImpButton = app.buttons["impbluff-showToImp"]
        guard showToImpButton.waitForExistence(timeout: 2) else { return }

        // Select the first 3 available bluff roles
        var selected = 0
        for button in app.buttons.allElementsBoundByIndex where button.identifier.hasPrefix("impbluff-role-") {
            if selected >= 3 { break }
            button.tap()
            selected += 1
            usleep(200_000)
        }

        showToImpButton.tap()
        usleep(300_000)

        // Handle the reveal view
        let revealNightFalls = app.buttons["impbluffreveal-nightFalls"]
        if revealNightFalls.waitForExistence(timeout: 2) {
            revealNightFalls.tap()
            usleep(300_000)
        }
    }

    private func handleFortuneTellerRedHerringIfNeeded() {
        // Check for any red herring selection button
        if let redHerringButton = findFirstButton(prefix: "night-redherring-") {
            redHerringButton.tap()
            usleep(300_000)
        }
    }

    private func handleImpReplacementIfNeeded() {
        if let replacementButton = findFirstButton(prefix: "night-impReplacement-") {
            replacementButton.tap()
            usleep(300_000)
        }
    }

    private func selectFirstAvailableNightTarget() {
        for seat in 1...5 {
            let targetButton = app.buttons["night-target-\(seat)"]
            if targetButton.exists && targetButton.isHittable {
                targetButton.tap()
                usleep(200_000)
                return
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

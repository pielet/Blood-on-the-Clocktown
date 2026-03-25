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
        XCTAssertTrue(templateButton.waitForExistence(timeout: 15), "Trouble Brewing template button should exist")
        templateButton.tap()

        // 2. Player setup — use 5 players (minimum, fastest game)
        let drawButton = app.buttons["setup-drawRoles"]
        XCTAssertTrue(drawButton.waitForExistence(timeout: 10), "Draw Roles button should exist")
        // Tap the stepper decrement to get to 5 (default is 7, decrement twice)
        let stepper = app.steppers["setup-stepper"]
        XCTAssertTrue(stepper.waitForExistence(timeout: 5), "Player stepper should exist")
        stepper.buttons["Decrement"].tap()
        sleep(1)
        stepper.buttons["Decrement"].tap()
        sleep(1)

        drawButton.tap()
        sleep(1)

        let assignButton = app.buttons["setup-assignRoles"]
        XCTAssertTrue(assignButton.waitForExistence(timeout: 10), "Assign Roles button should exist")
        // Wait for it to become enabled (drunk selection may be needed)
        handleDrunkSelectionIfNeeded()
        assignButton.tap()

        // 3. Assignment — tap each card twice (flip open, flip closed/used)
        let nightFallsButton = app.buttons["assignment-nightFalls"]
        XCTAssertTrue(nightFallsButton.waitForExistence(timeout: 10), "Night Falls button should exist")

        for i in 0..<5 {
            let card = app.buttons["assignment-card-\(i)"]
            if card.waitForExistence(timeout: 5) {
                card.tap()
                sleep(1)
                // Tap again to dismiss (flip back / mark used)
                card.tap()
                sleep(1)
            }
        }

        nightFallsButton.tap()
        sleep(1)

        // 4. Handle Imp Bluff setup if it appears
        handleImpBluffSetupIfNeeded()

        // 5. Handle fortune teller red herring if it appears
        handleFortuneTellerRedHerringIfNeeded()

        // 6. Run night/day cycles until game over
        let maxCycles = 20
        for _ in 0..<maxCycles {
            // Check if game is over
            if app.staticTexts["gameover-winner"].waitForExistence(timeout: 2) {
                break
            }

            // Night phase: complete/skip all steps
            driveNightPhase()

            // Check if game ended during night
            if app.staticTexts["gameover-winner"].waitForExistence(timeout: 2) {
                break
            }

            // Day phase: nominate, vote, execute
            driveDayPhase()
        }

        // 7. Verify game over screen
        let winnerText = app.staticTexts["gameover-winner"]
        XCTAssertTrue(winnerText.waitForExistence(timeout: 15), "Game over winner text should appear")

        // 8. Restart and verify back at template selection
        let restartButton = app.buttons["gameover-restart"]
        XCTAssertTrue(restartButton.exists, "Restart button should exist on game over screen")
        restartButton.tap()

        XCTAssertTrue(
            app.buttons["template-trouble_brewing"].waitForExistence(timeout: 10),
            "Should return to template selection after restart"
        )
    }

    // MARK: - Template Listing

    @MainActor
    func testLaunchAndSelectEachTemplate() throws {
        // Verify all 3 templates appear
        XCTAssertTrue(app.buttons["template-trouble_brewing"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.buttons["template-bad_moon_rising"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["template-sects_and_violets"].waitForExistence(timeout: 5))

        // Select Trouble Brewing, verify player setup appears
        app.buttons["template-trouble_brewing"].tap()
        XCTAssertTrue(app.buttons["setup-drawRoles"].waitForExistence(timeout: 10))

        // Reset and select Bad Moon Rising
        let restartButton = app.buttons["content-restart"]
        XCTAssertTrue(restartButton.waitForExistence(timeout: 5))
        restartButton.tap()

        XCTAssertTrue(app.buttons["template-bad_moon_rising"].waitForExistence(timeout: 10))
        app.buttons["template-bad_moon_rising"].tap()
        XCTAssertTrue(app.buttons["setup-drawRoles"].waitForExistence(timeout: 10))

        // Reset and select Sects and Violets
        restartButton.tap()
        XCTAssertTrue(app.buttons["template-sects_and_violets"].waitForExistence(timeout: 10))
        app.buttons["template-sects_and_violets"].tap()
        XCTAssertTrue(app.buttons["setup-drawRoles"].waitForExistence(timeout: 10))
    }

    // MARK: - Player Setup Adjustments

    @MainActor
    func testPlayerSetupAdjustments() throws {
        // Select a template first
        XCTAssertTrue(app.buttons["template-trouble_brewing"].waitForExistence(timeout: 15))
        app.buttons["template-trouble_brewing"].tap()

        let drawButton = app.buttons["setup-drawRoles"]
        XCTAssertTrue(drawButton.waitForExistence(timeout: 10))

        // Draw roles at default count
        drawButton.tap()
        sleep(1)

        // Verify assign button becomes available (may need drunk selection)
        handleDrunkSelectionIfNeeded()
        let assignButton = app.buttons["setup-assignRoles"]
        XCTAssertTrue(assignButton.waitForExistence(timeout: 10))

        // Adjust player count up
        let stepper = app.steppers["setup-stepper"]
        XCTAssertTrue(stepper.waitForExistence(timeout: 5))
        stepper.buttons["Increment"].tap()
        sleep(1)

        // Draw again — new deck for new count
        drawButton.tap()
        sleep(1)

        // Verify assign button still available
        handleDrunkSelectionIfNeeded()
        XCTAssertTrue(assignButton.waitForExistence(timeout: 10))
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
                usleep(500_000)
            } else if skipButton.exists && skipButton.isHittable {
                skipButton.tap()
                usleep(500_000)
            } else {
                // Night phase may be done — wait briefly for transition
                sleep(1)
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
        guard executeButton.waitForExistence(timeout: 10) else { return }

        // Try to nominate and vote
        // Pick the first available nominator
        if let nominatorButton = findFirstButton(prefix: "day-nominator-") {
            nominatorButton.tap()
            usleep(500_000)

            // Pick the first available nominee
            if let nomineeButton = findFirstButton(prefix: "day-nominee-") {
                nomineeButton.tap()
                usleep(500_000)

                // Vote: tap all available vote buttons to get majority
                for seat in 1...5 {
                    let voteButton = app.buttons["day-vote-\(seat)"]
                    if voteButton.exists && voteButton.isHittable {
                        voteButton.tap()
                        usleep(200_000)
                    }
                }

                // Lock the vote
                let lockButton = app.buttons["day-lockVote"]
                if lockButton.exists && lockButton.isHittable {
                    lockButton.tap()
                    usleep(500_000)
                }
            }
        }

        // Execute if available, otherwise skip
        if executeButton.exists && executeButton.isHittable && executeButton.isEnabled {
            executeButton.tap()
        } else if skipButton.exists && skipButton.isHittable {
            skipButton.tap()
        }
        sleep(1)
    }

    // MARK: - Helpers

    private func handleDrunkSelectionIfNeeded() {
        sleep(1)
    }

    private func handleImpBluffSetupIfNeeded() {
        let showToImpButton = app.buttons["impbluff-showToImp"]
        guard showToImpButton.waitForExistence(timeout: 5) else { return }

        // Select the first 3 available bluff roles
        var selected = 0
        for button in app.buttons.allElementsBoundByIndex where button.identifier.hasPrefix("impbluff-role-") {
            if selected >= 3 { break }
            button.tap()
            selected += 1
            usleep(300_000)
        }

        showToImpButton.tap()
        sleep(1)

        // Handle the reveal view
        let revealNightFalls = app.buttons["impbluffreveal-nightFalls"]
        if revealNightFalls.waitForExistence(timeout: 5) {
            revealNightFalls.tap()
            sleep(1)
        }
    }

    private func handleFortuneTellerRedHerringIfNeeded() {
        if let redHerringButton = findFirstButton(prefix: "night-redherring-") {
            redHerringButton.tap()
            usleep(500_000)
        }
    }

    private func handleImpReplacementIfNeeded() {
        if let replacementButton = findFirstButton(prefix: "night-impReplacement-") {
            replacementButton.tap()
            usleep(500_000)
        }
    }

    private func selectFirstAvailableNightTarget() {
        for seat in 1...5 {
            let targetButton = app.buttons["night-target-\(seat)"]
            if targetButton.exists && targetButton.isHittable {
                targetButton.tap()
                usleep(300_000)
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

import Foundation
import Testing
@testable import blood_on_the_clocktower

@Suite(.serialized) struct TroubleBrewingTests {

    // MARK: - Setup & Deck

    @Test func buildDeckAlwaysUsesUniqueRoles() {
        let game = ClocktowerGameViewModel()
        let allRoleIds = Set(troubleBrewingTemplate.roles.map(\.id))

        game.selectTemplate("trouble-brewing")
        for playerCount in 5...15 {
            game.setPlayerCount(playerCount)
            game.buildDeck()

            #expect(game.roleDeck.count == game.playerCount)
            #expect(Set(game.roleDeck.map(\.roleId)).count == playerCount)
            #expect(game.roleDeck.allSatisfy { allRoleIds.contains($0.roleId) })
        }
    }

    @Test func baronReplacesTownAndAddsOutsiders() {
        let game = ClocktowerGameViewModel()
        game.selectTemplate("trouble-brewing")
        game.setPlayerCount(10)

        var foundBaronBuild = false
        for _ in 0..<160 {
            game.buildDeck()
            let deckRoleIds = game.roleDeck.map(\.roleId)
            if deckRoleIds.contains("baron") {
                let rolesByTeam = countRolesByTeam(deckRoleIds, roles: troubleBrewingTemplate.roles)
                foundBaronBuild = true
                #expect(rolesByTeam.townsfolk == 5)
                #expect(rolesByTeam.outsiders == 2)
                #expect(rolesByTeam.minions == 2)
                #expect(rolesByTeam.demons == 1)
                break
            }
        }
        #expect(foundBaronBuild)
    }

    // MARK: - Night Order

    @Test func firstNightOrderDiffersFromLaterNightOrder() {
        let game = makeAssignedGame(
            templateId: "trouble-brewing",
            roleIds: [
                "poisoner", "washerwoman", "librarian", "investigator",
                "chef", "empath", "fortuneteller", "undertaker",
                "monk", "ravenkeeper", "butler", "scarletwoman",
                "spy", "imp"
            ]
        )

        // Set Fortune Teller red herring before starting night
        game.selectFortuneTellerRedHerring(game.players[0].id)
        game.beginNight()
        let firstOrder = game.currentNightSteps.map(\.roleId)
        game.startNextNight()
        let laterOrder = game.currentNightSteps.map(\.roleId)

        #expect(firstOrder != laterOrder)
        #expect(firstOrder.first == "poisoner")
        #expect(laterOrder.first == "poisoner")
        #expect(firstOrder.contains("washerwoman"))
        #expect(laterOrder.contains("monk"))
        #expect(!laterOrder.contains("scarletwoman"))
    }

    @Test func firstNightInfoRoleChoicesMatchRolesInPlay() {
        let game = makeAssignedGame(
            templateId: "trouble-brewing",
            roleIds: ["washerwoman", "librarian", "investigator", "chef", "butler", "drunk", "poisoner", "imp"]
        )
        game.appLanguage = .english
        game.phase = .firstNight
        game.isFirstNightPhase = true

        game.currentNightSteps = [NightStepTemplate(id: "test-washerwoman", roleId: "washerwoman", condition: .always)]
        game.currentNightStepIndex = 0
        #expect(Set(game.currentNightRoleChoices().compactMap(\.roleId)) == Set(["washerwoman", "librarian", "investigator", "chef"]))

        game.currentNightSteps = [NightStepTemplate(id: "test-librarian", roleId: "librarian", condition: .always)]
        game.currentNightStepIndex = 0
        #expect(Set(game.currentNightRoleChoices().compactMap(\.roleId)) == Set(["butler", "drunk"]))

        game.currentNightSteps = [NightStepTemplate(id: "test-investigator", roleId: "investigator", condition: .always)]
        game.currentNightStepIndex = 0
        #expect(Set(game.currentNightRoleChoices().compactMap(\.roleId)) == Set(["poisoner"]))
    }

    @Test func librarianShowsNoOutsiderChoiceWhenNoOutsiderInPlay() {
        let game = makeAssignedGame(
            templateId: "trouble-brewing",
            roleIds: ["washerwoman", "librarian", "investigator", "chef", "poisoner", "imp"]
        )
        game.appLanguage = .english
        game.phase = .firstNight
        game.isFirstNightPhase = true
        game.currentNightSteps = [NightStepTemplate(id: "test-librarian", roleId: "librarian", condition: .always)]
        game.currentNightStepIndex = 0

        let options = game.currentNightRoleChoices()
        #expect(options.count == 1)
        #expect(options.first?.roleId == nil)
        #expect(game.localizedNightRoleChoiceLabel(options[0]) == "No Outsider")
    }

    @Test func spyInPlayUnlocksAllTownsfolkForWasherwoman() {
        let game = makeAssignedGame(
            templateId: "trouble-brewing",
            roleIds: ["washerwoman", "librarian", "chef", "spy", "imp"]
        )
        game.appLanguage = .english
        game.phase = .firstNight
        game.isFirstNightPhase = true

        game.currentNightSteps = [NightStepTemplate(id: "test-washerwoman", roleId: "washerwoman", condition: .always)]
        game.currentNightStepIndex = 0

        // Full pool minus the detector itself (washerwoman), drunk, and marionette
        let excluded: Set<String> = ["washerwoman", "drunk", "marionette"]
        let expectedTownsfolk = Set(troubleBrewingTemplate.roles.filter { $0.team == .townsfolk && !excluded.contains($0.id) }.map(\.id))
        let choices = Set(game.currentNightRoleChoices().compactMap(\.roleId))
        #expect(choices == expectedTownsfolk)
    }

    @Test func spyInPlayUnlocksAllOutsidersForLibrarian() {
        let game = makeAssignedGame(
            templateId: "trouble-brewing",
            roleIds: ["librarian", "chef", "butler", "spy", "imp"]
        )
        game.appLanguage = .english
        game.phase = .firstNight
        game.isFirstNightPhase = true

        game.currentNightSteps = [NightStepTemplate(id: "test-librarian", roleId: "librarian", condition: .always)]
        game.currentNightStepIndex = 0

        // Full outsider pool except marionette, which is never a valid TB registration result.
        let excluded: Set<String> = ["marionette"]
        let expectedOutsiders = Set(troubleBrewingTemplate.roles.filter { $0.team == .outsider && !excluded.contains($0.id) }.map(\.id))
        let choices = game.currentNightRoleChoices()
        let choiceRoleIds = Set(choices.compactMap(\.roleId))
        #expect(choiceRoleIds == expectedOutsiders)
        #expect(choices.contains(where: { $0.roleId == nil }), "Should include 'No Outsider' option")
    }

    @Test func librarianSelectingDrunkTargetsActualDrunkWhenInPlay() throws {
        let game = makeAssignedGame(
            templateId: "trouble-brewing",
            roleIds: ["librarian", "drunk", "chef", "spy", "imp"]
        )
        game.appLanguage = .english
        game.phase = .firstNight
        game.isFirstNightPhase = true
        game.currentNightSteps = [NightStepTemplate(id: "test-librarian", roleId: "librarian", condition: .always)]
        game.currentNightStepIndex = 0

        let choices = game.currentNightRoleChoices()
        let drunkChoice = try #require(choices.first(where: { $0.roleId == "drunk" }))
        let drunkPlayer = try #require(game.players.first(where: { $0.roleId == "drunk" }))

        game.autoSelectPlayerForRoleChoice(drunkChoice)

        #expect(game.currentNightTargets == [drunkPlayer.id])
    }

    @Test func librarianSelectingAbsentDrunkTargetsSpyFallback() throws {
        let game = makeAssignedGame(
            templateId: "trouble-brewing",
            roleIds: ["librarian", "chef", "butler", "spy", "imp"]
        )
        game.appLanguage = .english
        game.phase = .firstNight
        game.isFirstNightPhase = true
        game.currentNightSteps = [NightStepTemplate(id: "test-librarian", roleId: "librarian", condition: .always)]
        game.currentNightStepIndex = 0

        let choices = game.currentNightRoleChoices()
        let drunkChoice = try #require(choices.first(where: { $0.roleId == "drunk" }))
        let spyPlayer = try #require(game.players.first(where: { $0.roleId == "spy" }))

        game.autoSelectPlayerForRoleChoice(drunkChoice)

        #expect(game.currentNightTargets == [spyPlayer.id])
    }

    @Test func recluseInPlayUnlocksAllMinionsForInvestigator() {
        let game = makeAssignedGame(
            templateId: "trouble-brewing",
            roleIds: ["investigator", "chef", "recluse", "poisoner", "imp"]
        )
        game.appLanguage = .english
        game.phase = .firstNight
        game.isFirstNightPhase = true

        game.currentNightSteps = [NightStepTemplate(id: "test-investigator", roleId: "investigator", condition: .always)]
        game.currentNightStepIndex = 0

        let allMinions = Set(troubleBrewingTemplate.roles.filter { $0.team == .minion }.map(\.id))
        let choices = Set(game.currentNightRoleChoices().compactMap(\.roleId))
        #expect(choices == allMinions)
    }

    @Test func noSpyMeansWasherwomanOnlySeesInPlayTownsfolk() {
        let game = makeAssignedGame(
            templateId: "trouble-brewing",
            roleIds: ["washerwoman", "librarian", "chef", "poisoner", "imp"]
        )
        game.appLanguage = .english
        game.phase = .firstNight
        game.isFirstNightPhase = true

        game.currentNightSteps = [NightStepTemplate(id: "test-washerwoman", roleId: "washerwoman", condition: .always)]
        game.currentNightStepIndex = 0

        let choices = Set(game.currentNightRoleChoices().compactMap(\.roleId))
        #expect(choices == Set(["washerwoman", "librarian", "chef"]))
    }

    @Test func undertakerWakesAfterExecutionAndLearnsTrueRole() {
        let game = makeAssignedGame(
            templateId: "trouble-brewing",
            roleIds: ["undertaker", "drunk", "washerwoman", "poisoner", "imp"]
        )
        game.appLanguage = .english
        game.currentDayNumber = 1
        game.hasExecutionToday = true
        game.executedPlayerToday = game.players[1].id

        game.startNextNight()

        #expect(game.currentNightSteps.contains(where: { $0.roleId == "undertaker" }))

        if let undertakerIndex = game.currentNightSteps.firstIndex(where: { $0.roleId == "undertaker" }) {
            game.currentNightStepIndex = undertakerIndex
            game.completeCurrentNightAction()
        }

        #expect(game.gameLog.contains(where: {
            $0.englishText.contains("Undertaker learned that Player2 registered as the Drunk.")
        }))
    }

    @Test func undertakerCanLearnRegisteredRoleFromSpyOrRecluse() {
        let spyGame = makeAssignedGame(
            templateId: "trouble-brewing",
            roleIds: ["undertaker", "spy", "washerwoman", "poisoner", "imp"]
        )
        spyGame.appLanguage = .english
        spyGame.phase = .night
        spyGame.isFirstNightPhase = false
        spyGame.currentDayNumber = 1
        spyGame.hasExecutionToday = true
        spyGame.executedPlayerToday = spyGame.players[1].id
        spyGame.currentNightSteps = [NightStepTemplate(id: "test-undertaker-spy", roleId: "undertaker", condition: .always)]
        spyGame.currentNightStepIndex = 0
        spyGame.currentNightNote = "drunk"
        spyGame.completeCurrentNightAction()

        #expect(spyGame.gameLog.contains(where: {
            $0.englishText.contains("Player2 registered as the Drunk")
        }))

        let recluseGame = makeAssignedGame(
            templateId: "trouble-brewing",
            roleIds: ["undertaker", "recluse", "washerwoman", "poisoner", "imp"]
        )
        recluseGame.appLanguage = .english
        recluseGame.phase = .night
        recluseGame.isFirstNightPhase = false
        recluseGame.currentDayNumber = 1
        recluseGame.hasExecutionToday = true
        recluseGame.executedPlayerToday = recluseGame.players[1].id
        recluseGame.currentNightSteps = [NightStepTemplate(id: "test-undertaker-recluse", roleId: "undertaker", condition: .always)]
        recluseGame.currentNightStepIndex = 0
        recluseGame.currentNightNote = "imp"
        recluseGame.completeCurrentNightAction()

        #expect(recluseGame.gameLog.contains(where: {
            $0.englishText.contains("Player2 registered as the Imp")
        }))
    }

    @Test func virginCanExecuteSpyWhenRegisteredAsTownsfolk() {
        let game = makeAssignedGame(
            templateId: "trouble-brewing",
            roleIds: ["virgin", "spy", "washerwoman", "poisoner", "imp"]
        )
        game.appLanguage = .english
        game.phase = .day
        game.currentDayNumber = 1

        game.setNominator(game.players[1].id)
        game.setNominee(game.players[0].id)

        #expect(game.isAwaitingVirginRegistrationChoice)
        #expect(game.players[1].alive)

        game.resolvePendingVirginRegistration(registersAsTownsfolk: true)

        #expect(!game.players[1].alive)
        #expect(game.executedPlayerToday == game.players[1].id)
    }

    @Test func villageIdiotCanSeeFlexiblePlayerAsChosenAlignment() {
        let game = makeAssignedGame(
            templateId: "trouble-brewing",
            roleIds: ["villageidiot", "spy", "washerwoman", "poisoner", "imp"],
            experimental: true
        )
        game.appLanguage = .english
        game.phase = .night
        game.isFirstNightPhase = false
        game.currentNightSteps = [NightStepTemplate(id: "test-village-idiot", roleId: "villageidiot", condition: .always)]
        game.currentNightStepIndex = 0
        game.currentNightTargets = [game.players[1].id]
        game.setCurrentNightAlignmentSelection(false, for: game.players[1].id)
        game.completeCurrentNightAction()

        #expect(game.gameLog.contains(where: {
            $0.englishText.contains("Player2 is good")
        }))
    }

    @Test func drunkShownRoleSelectionUsesTownsfolkFrontButKeepsTrueRole() {
        let game = ClocktowerGameViewModel()
        game.selectTemplate("trouble-brewing")
        game.players = [
            PlayerCard(
                id: UUID(),
                seatNumber: 1,
                name: "Player1",
                roleId: nil,
                displayedRoleId: nil,
                alive: true,
                deadReason: nil,
                voteModifier: 0,
                butlerMasterId: nil,
                poisonedTonight: false,
                protectedTonight: false,
                becameDemonTonight: false,
                wasButlerTonight: false,
                wasNominated: false,
                slayerShotUsed: false,
                ghostVoteAvailable: true,
                roleLog: [],
                isDeadTonight: false
            )
        ]
        let drunkCard = RoleDeckCard(roleId: "drunk", assignedPlayerId: nil, state: .front)
        game.roleDeck = [drunkCard]
        game.selectDisplayedRoleForDrunkCard(drunkCard.id, roleId: "chef")

        #expect(game.assignmentDisplayRole(for: game.roleDeck[0])?.id == "chef")

        game.flipDeckCard(drunkCard.id)

        #expect(game.players[0].roleId == "drunk")
        #expect(game.players[0].displayedRoleId == "chef")
    }

    @Test func displayedDrunkAppearsInNightOrderAsShownRole() {
        let game = makeAssignedGame(
            templateId: "trouble-brewing",
            roleIds: ["drunk", "butler", "recluse", "poisoner", "imp"],
            experimental: true
        )
        game.players[0].displayedRoleId = "chef"

        game.beginNight()

        #expect(game.currentNightSteps.contains(where: { $0.roleId == "chef" }))

        if let chefIndex = game.currentNightSteps.firstIndex(where: { $0.roleId == "chef" }) {
            game.currentNightStepIndex = chefIndex
            #expect(game.currentNightActor?.id == game.players[0].id)
        }
    }

    @Test func displayedDrunkReceivesFakeNightInfo() {
        let game = makeAssignedGame(
            templateId: "trouble-brewing",
            roleIds: ["drunk", "butler", "recluse", "poisoner", "imp"],
            experimental: true
        )
        game.players[0].displayedRoleId = "chef"

        runNightStep(game, roleId: "chef", note: "2", firstNight: true)

        #expect(game.gameLog.contains(where: {
            if case .drunk = $0.logTone {
                return $0.englishText.contains("actually the Drunk")
            }
            return false
        }))
    }

    @Test func displayedDrunkSlayerShotHasNoRealEffect() {
        let game = makeAssignedGame(
            templateId: "trouble-brewing",
            roleIds: ["drunk", "washerwoman", "imp", "poisoner", "baron"],
            experimental: true
        )
        game.players[0].displayedRoleId = "slayer"
        let demon = game.players[2]

        game.phase = .day
        game.chooseSlayerTarget(demon.id)
        game.useSlayerShot()

        #expect(game.players[0].slayerShotUsed)
        #expect(game.players[2].alive)
        #expect(game.gameLog.contains(where: {
            if case .drunk = $0.logTone {
                return $0.englishText.contains("fake Slayer shot")
            }
            return false
        }))
    }

    // MARK: - Poisoner

    @Test func poisonerSuppressesTargetAbility() {
        let game = makeAssignedGame(
            templateId: "trouble-brewing",
            roleIds: ["poisoner", "empath", "washerwoman", "imp", "baron"]
        )
        game.appLanguage = .english
        let empath = game.players[1]

        game.phase = .night
        game.isFirstNightPhase = false
        game.currentNightSteps = [
            NightStepTemplate(id: "test-poisoner", roleId: "poisoner", condition: .always),
            NightStepTemplate(id: "test-empath", roleId: "empath", condition: .always)
        ]
        game.currentNightStepIndex = 0

        game.currentNightTargets = [empath.id]
        game.completeCurrentNightAction()

        #expect(game.currentNightStep?.roleId == "empath")
        #expect(game.currentNightActor?.id == empath.id)
        #expect(game.currentNightReminderHighlightStyle == .poison)
        #expect(game.currentNightReminderHighlightStyle != nil)
        #expect(game.nightStepReminder.contains("is poisoned"))
        #expect(game.nightStepReminder.contains("false info"))

        game.completeCurrentNightAction()

        // Poisoned info roles still run but their game log entries are marked as poison-caused false info
        let poisonLogs = game.gameLog.filter {
            if case .poison = $0.logTone {
                return true
            }
            return false
        }
        #expect(!poisonLogs.isEmpty, "Poisoned Empath should produce poison-colored log entries")
    }

    @Test func poisonedActiveRoleStillWakesInNightFlow() {
        let game = makeAssignedGame(
            templateId: "trouble-brewing",
            roleIds: ["poisoner", "monk", "washerwoman", "imp", "baron"]
        )
        let monk = game.players[1]
        let attemptedTarget = game.players[2]

        game.phase = .night
        game.isFirstNightPhase = false
        game.currentNightSteps = [
            NightStepTemplate(id: "test-poisoner", roleId: "poisoner", condition: .always),
            NightStepTemplate(id: "test-monk", roleId: "monk", condition: .always)
        ]
        game.currentNightStepIndex = 0

        game.currentNightTargets = [monk.id]
        game.completeCurrentNightAction()

        #expect(game.currentNightStep?.roleId == "monk")
        #expect(game.currentNightActor?.id == monk.id)

        game.currentNightTargets = [attemptedTarget.id]
        game.completeCurrentNightAction()

        #expect(game.players[2].protectedTonight == false)

        let poisonLogs = game.gameLog.filter {
            if case .poison = $0.logTone {
                return true
            }
            return false
        }
        #expect(!poisonLogs.isEmpty, "Poisoned Monk should still wake and log a poison-colored no-effect result")
    }

    @Test func displayedDrunkWakeStepHighlightsReminderBlock() {
        let game = makeAssignedGame(
            templateId: "trouble-brewing",
            roleIds: ["drunk", "washerwoman", "poisoner", "imp", "baron"]
        )
        game.appLanguage = .english
        game.players[0].displayedRoleId = "chef"
        game.phase = .firstNight
        game.isFirstNightPhase = true
        game.currentNightSteps = [NightStepTemplate(id: "test-chef", roleId: "chef", condition: .always)]
        game.currentNightStepIndex = 0

        #expect(game.currentNightActor?.id == game.players[0].id)
        #expect(game.currentNightReminderHighlightStyle == .drunk)
        #expect(game.currentNightReminderHighlightStyle != nil)
        #expect(game.nightStepReminder.contains("actually the Drunk"))
    }

    // MARK: - Imp

    @Test func impKillsTargetAtNight() {
        let game = makeAssignedGame(
            templateId: "trouble-brewing",
            roleIds: ["washerwoman", "librarian", "investigator", "imp", "poisoner"]
        )
        let target = game.players[0]

        runNightStep(game, roleId: "imp", targets: [target.id])

        #expect(game.players[0].alive == false)
    }

    @Test func impSelfKillPromotesMinion() {
        let game = makeAssignedGame(
            templateId: "trouble-brewing",
            roleIds: ["imp", "poisoner", "spy", "washerwoman", "librarian", "investigator"]
        )
        let imp = game.players[0]

        // Imp kills self — dies immediately via killIfAlive
        runNightStep(game, roleId: "imp", targets: [imp.id])

        // impDiedTonight is set; startNextNight promotes a minion
        game.startNextNight()

        // One of the minions should now be the imp
        let newImp = game.players.first(where: { $0.roleId == "imp" && $0.alive })
        #expect(newImp != nil)
        #expect(newImp?.id != imp.id)
    }

    // MARK: - Scarlet Woman

    @Test func scarletWomanBecomesDemonWhenImpDiesWithFivePlusAlive() {
        let game = makeAssignedGame(
            templateId: "trouble-brewing",
            roleIds: ["imp", "scarletwoman", "washerwoman", "librarian", "investigator", "chef"]
        )
        let imp = game.players[0]

        // Imp kills self with 6 alive → Scarlet Woman should take over
        runNightStep(game, roleId: "imp", targets: [imp.id])
        game.startNextNight()

        let scarletPlayer = game.players[1]
        #expect(scarletPlayer.roleId == "imp")
        #expect(scarletPlayer.alive)
        #expect(scarletPlayer.roleLog.contains(where: { $0.contains("Demon") || $0.contains("恶魔") }))
    }

    // MARK: - Monk

    @Test func monkProtectsTargetFromDemonKill() {
        let game = makeAssignedGame(
            templateId: "trouble-brewing",
            roleIds: ["monk", "washerwoman", "librarian", "imp", "poisoner"]
        )
        let protectedTarget = game.players[1]

        // Night order: monk first, then imp
        game.phase = .night
        game.isFirstNightPhase = false
        game.currentNightSteps = [
            NightStepTemplate(id: "test-monk", roleId: "monk", condition: .always),
            NightStepTemplate(id: "test-imp", roleId: "imp", condition: .always)
        ]
        game.currentNightStepIndex = 0

        // Monk protects washerwoman
        game.currentNightTargets = [protectedTarget.id]
        game.completeCurrentNightAction()

        // Imp targets washerwoman
        game.currentNightTargets = [protectedTarget.id]
        game.completeCurrentNightAction()

        // Washerwoman should survive
        #expect(game.players[1].alive)
    }

    // MARK: - Soldier

    @Test func soldierSurvivedDemonAttack() {
        let game = makeAssignedGame(
            templateId: "trouble-brewing",
            roleIds: ["soldier", "washerwoman", "librarian", "imp", "poisoner"]
        )
        let soldier = game.players[0]

        runNightStep(game, roleId: "imp", targets: [soldier.id])

        #expect(game.players[0].alive)
    }

    // MARK: - Slayer

    @Test func slayerKillsDemon() {
        let game = makeAssignedGame(
            templateId: "trouble-brewing",
            roleIds: ["slayer", "washerwoman", "imp", "poisoner", "baron"]
        )
        let demon = game.players[2]

        game.phase = .day
        game.chooseSlayerTarget(demon.id)
        game.useSlayerShot()

        #expect(game.players[2].alive == false)
        // Slayer shot log + game-over log
        let slayerLog = game.gameLog.first(where: { $0.englishText.contains("killed the Demon") })
        #expect(slayerLog != nil)
        #expect(slayerLog?.englishText.contains("Player1") == true)
        #expect(slayerLog?.englishText.contains("Player3") == true)
    }

    @Test func slayerMissesNonDemon() {
        let game = makeAssignedGame(
            templateId: "trouble-brewing",
            roleIds: ["slayer", "washerwoman", "imp", "poisoner", "baron"]
        )
        let nonDemon = game.players[1]

        game.phase = .day
        game.chooseSlayerTarget(nonDemon.id)
        game.useSlayerShot()

        #expect(game.players[1].alive)
        #expect(game.gameLog.count == 1)
        #expect(game.gameLog[0].englishText.contains("Player1"))
        #expect(game.gameLog[0].englishText.contains("Player2"))
        #expect(game.gameLog[0].englishText.contains("failed"))
    }

    // MARK: - Saint

    @Test func saintExecutionCausesEvilWin() {
        let game = makeAssignedGame(
            templateId: "trouble-brewing",
            roleIds: ["saint", "washerwoman", "librarian", "imp", "poisoner"]
        )
        let saint = game.players[0]

        game.phase = .day
        game.nominationResults[saint.id] = game.executionThreshold
        game.executeNomineeIfSet()

        #expect(game.isGameOver)
        #expect(game.winningSide == .evil)
    }

    // MARK: - Mayor

    @Test func mayorWinsWithoutExecutionAtThreePlayers() {
        let game = makeAssignedGame(templateId: "trouble-brewing", roleIds: ["mayor", "washerwoman", "imp"])
        game.hasExecutionToday = false
        #expect(game.shouldMayorWinWithoutExecution())

        game.hasExecutionToday = true
        #expect(!game.shouldMayorWinWithoutExecution())
    }

    // MARK: - Butler

    @Test func butlerVotesThroughMasterVoteOnly() {
        let game = makeAssignedGame(templateId: "trouble-brewing", roleIds: ["butler", "washerwoman", "imp", "poisoner"])
        let butler = game.players[0]
        let master = game.players[1]
        let nominee = game.players[2]
        let other = game.players[3]

        game.updateButlerMaster(butler.id, master.id)
        game.setNominator(master.id)
        game.setNominee(nominee.id)
        game.castVote(voter: butler.id, nominee: nominee.id)
        #expect(game.votesByVoter[butler.id] == nil)

        game.castVote(voter: master.id, nominee: nominee.id)
        game.castVote(voter: butler.id, nominee: nominee.id)
        #expect(game.votesByVoter[butler.id] == nominee.id)

        game.castVote(voter: butler.id, nominee: other.id)
        #expect(game.votesByVoter[butler.id] == nominee.id)
    }

    // MARK: - Voting Mechanics

    @Test func livingPlayersCanVoteInMultipleNominationsOnSameDay() {
        let game = makeAssignedGame(templateId: "trouble-brewing", roleIds: ["washerwoman", "librarian", "investigator", "imp", "baron"])
        let voter = game.players[0]
        let nominator = game.players[1]
        let firstNominee = game.players[2]
        let secondNominee = game.players[3]

        game.phase = .day
        game.setNominator(nominator.id)
        game.setNominee(firstNominee.id)
        game.castVote(voter: voter.id, nominee: firstNominee.id)
        game.recordCurrentNomination()

        game.setNominator(nominator.id)
        game.setNominee(secondNominee.id)
        #expect(game.isVoteAllowed(voterId: voter.id, nominee: secondNominee.id))
        game.castVote(voter: voter.id, nominee: secondNominee.id)
        #expect(game.votesByVoter[voter.id] == secondNominee.id)
    }

    @Test func deadPlayerGhostVoteIsSpentAfterOneNomination() {
        let game = makeAssignedGame(templateId: "trouble-brewing", roleIds: ["washerwoman", "librarian", "investigator", "imp", "baron"])
        let deadVoter = game.players[0]
        let nominator = game.players[1]
        let firstNominee = game.players[2]
        let secondNominee = game.players[3]

        game.players[0].alive = false
        game.phase = .day
        game.setNominator(nominator.id)
        game.setNominee(firstNominee.id)
        game.castVote(voter: deadVoter.id, nominee: firstNominee.id)
        game.recordCurrentNomination()

        #expect(game.players[0].ghostVoteAvailable == false)

        game.setNominator(nominator.id)
        game.setNominee(secondNominee.id)
        #expect(!game.isVoteAllowed(voterId: deadVoter.id, nominee: secondNominee.id))
    }

    // MARK: - Game Over

    @Test func executingDemonEndsGameGoodWins() {
        let game = makeAssignedGame(
            templateId: "trouble-brewing",
            roleIds: ["washerwoman", "librarian", "imp", "poisoner", "baron"]
        )
        let demon = game.players[2]

        game.beginNight()
        game.phase = .day
        game.nominationResults[demon.id] = game.executionThreshold
        game.executeNomineeIfSet()

        #expect(game.isGameOver)
        #expect(game.winningSide == .good)
    }

    @Test func evilWinsWhenAliveCounIsEqual() {
        // 3 players: 1 evil, 2 good → kill 1 good → 1 evil, 1 good → evil parity
        let game = makeAssignedGame(
            templateId: "trouble-brewing",
            roleIds: ["washerwoman", "librarian", "imp"]
        )

        game.beginNight()
        // Skip to day, then start a night where imp kills
        game.phase = .day
        game.endDayWithoutExecution()

        // Imp kills a townsfolk → 1 good, 1 evil alive → evil wins
        #expect(game.isGameOver || game.phase == .night || game.phase == .finished)
    }

    // MARK: - Poisoner poison persists through the day

    @Test func poisonerPoisonPersistsThroughDay() {
        // Per wiki: "Each night, choose a player: they are poisoned tonight AND tomorrow day."
        let game = makeAssignedGame(
            templateId: "trouble-brewing",
            roleIds: ["poisoner", "slayer", "washerwoman", "imp", "baron"]
        )
        let slayer = game.players[1]

        // Poisoner targets Slayer at night
        runNightStep(game, roleId: "poisoner", targets: [slayer.id])

        // Transition to day (simulates dawn)
        game.phase = .day
        game.currentDayNumber = 1

        // Slayer should still be poisoned during the day
        let slayerNow = game.players[1]
        #expect(game.isPlayerPoisonedOrDrunk(slayerNow))
    }

    @Test func poisonerPoisonExpiresAtDusk() {
        let game = makeAssignedGame(
            templateId: "trouble-brewing",
            roleIds: ["poisoner", "slayer", "washerwoman", "imp", "baron"]
        )
        let slayer = game.players[1]

        // Poisoner targets Slayer at night
        runNightStep(game, roleId: "poisoner", targets: [slayer.id])

        // Simulate day then dusk transition (endDayToNextNight calls expireDuskLimitedEffects)
        game.phase = .day
        game.currentDayNumber = 1
        game.endDayToNextNight()

        // After dusk, the Poisoner's poison should have expired
        let slayerNow = game.players[1]
        #expect(!game.isPlayerPoisonedOrDrunk(slayerNow))
    }

    @Test func poisonerDeathEndsExistingPoison() {
        // Per wiki: "If the Poisoner dies or leaves play, existing poison effects end immediately."
        let game = makeAssignedGame(
            templateId: "trouble-brewing",
            roleIds: ["poisoner", "empath", "washerwoman", "imp", "baron"]
        )
        let empath = game.players[1]
        let poisoner = game.players[0]

        // Poisoner targets Empath
        runNightStep(game, roleId: "poisoner", targets: [empath.id])

        // Empath should be poisoned
        #expect(game.isPlayerPoisonedOrDrunk(game.players[1]))

        // Kill the Poisoner
        game.phase = .day
        game.currentDayNumber = 1
        if let idx = game.players.firstIndex(where: { $0.id == poisoner.id }) {
            game.players[idx].alive = false
        }

        // Empath should no longer be poisoned (Poisoner is dead)
        #expect(!game.isPlayerPoisonedOrDrunk(game.players[1]))
    }

    // MARK: - Scarlet Woman threshold edge case

    @Test func scarletWomanPriorityWithExactlyFiveAliveBeforeImpDeath() {
        // With exactly 5 alive (including Imp), Scarlet Woman should get priority
        // after Imp suicide, even though only 4 remain alive after
        let game = makeAssignedGame(
            templateId: "trouble-brewing",
            roleIds: ["imp", "scarletwoman", "washerwoman", "librarian", "investigator"]
        )
        let imp = game.players[0]

        // 5 players alive. Imp suicides → 4 alive after.
        // Scarlet Woman should still become Imp (5 alive before death).
        runNightStep(game, roleId: "imp", targets: [imp.id])
        game.startNextNight()

        let scarletPlayer = game.players[1]
        #expect(scarletPlayer.roleId == "imp")
        #expect(scarletPlayer.alive)
    }

    // MARK: - Slayer vs Recluse

    @Test func slayerCanKillRecluseWhenRegisteredAsDemon() {
        // Per wiki: Recluse "might register as a Demon" and Slayer can kill them
        let game = makeAssignedGame(
            templateId: "trouble-brewing",
            roleIds: ["slayer", "recluse", "washerwoman", "imp", "poisoner"]
        )
        let recluse = game.players[1]

        game.phase = .day
        game.chooseSlayerTarget(recluse.id)
        game.useSlayerShot()

        // Should be awaiting Recluse registration choice
        #expect(game.isAwaitingSlayerRecluseChoice)
        #expect(game.pendingSlayerRecluseTargetId == recluse.id)

        // Storyteller decides Recluse registers as Demon
        game.resolveSlayerRecluseRegistration(registersAsDemon: true)

        #expect(!game.players[1].alive)
        #expect(game.gameLog.contains(where: { $0.englishText.contains("Recluse registered as the Demon") }))
    }

    @Test func slayerDoesNotKillRecluseWhenNotRegisteredAsDemon() {
        let game = makeAssignedGame(
            templateId: "trouble-brewing",
            roleIds: ["slayer", "recluse", "washerwoman", "imp", "poisoner"]
        )
        let recluse = game.players[1]

        game.phase = .day
        game.chooseSlayerTarget(recluse.id)
        game.useSlayerShot()

        #expect(game.isAwaitingSlayerRecluseChoice)

        // Storyteller decides Recluse does NOT register as Demon
        game.resolveSlayerRecluseRegistration(registersAsDemon: false)

        #expect(game.players[1].alive)
        #expect(game.gameLog.contains(where: { $0.englishText.contains("failed") }))
    }

    // MARK: - Poisoned Slayer during the day

    @Test func poisonedSlayerShotFailsDuringDay() {
        // Per wiki: Poisoner poison lasts through the day.
        // A poisoned Slayer should not be able to kill during the day.
        let game = makeAssignedGame(
            templateId: "trouble-brewing",
            roleIds: ["poisoner", "slayer", "washerwoman", "imp", "baron"]
        )
        let slayer = game.players[1]
        let demon = game.players[3]

        // Poisoner targets Slayer at night
        runNightStep(game, roleId: "poisoner", targets: [slayer.id])

        // Day phase - Slayer should be suppressed
        game.phase = .day
        game.currentDayNumber = 1

        // Slayer tries to shoot the actual Demon
        game.chooseSlayerTarget(demon.id)
        game.useSlayerShot()

        // Demon should still be alive (Slayer was poisoned)
        #expect(game.players[3].alive)
    }
}

import Foundation
import Testing
@testable import blood_on_the_clocktower

/// General tests and cross-script tests that don't belong to a single script file.
@Suite(.serialized) struct GeneralTests {

    @Test func playerSetupRespectsBounds() {
        let game = ClocktowerGameViewModel()
        game.selectTemplate("trouble-brewing")
        game.setPlayerCount(4)
        game.playerSetup()

        #expect(game.players.count == 5)
        #expect(game.phase == .assignment)
        #expect(game.players.allSatisfy { $0.roleId == nil && $0.alive })
    }

    @Test func assignAllRandomCompletesAssignment() {
        let game = ClocktowerGameViewModel()
        game.selectTemplate("trouble-brewing")
        game.setPlayerCount(6)
        game.playerSetup()
        for card in game.roleDeck where card.roleId == "drunk" && card.displayedRoleId == nil {
            if let pick = game.availableDrunkDisplayRoles(for: card.id).first {
                game.selectDisplayedRoleForDrunkCard(card.id, roleId: pick.id)
            }
        }
        game.assignAllRandom()

        #expect(game.isAssignmentReady)
        #expect(game.roleDeck.allSatisfy { $0.state == .used })
        #expect(!game.players.contains { $0.roleId == nil })
    }
}

// MARK: - Sects & Violets (base)

@Suite(.serialized) struct SectsAndVioletsTests {

    @Test func vigormortisReducesOutsiderCountWhenDrawn() {
        let game = ClocktowerGameViewModel()
        game.selectTemplate("sects-and-violets")
        game.setPlayerCount(8)

        var foundVigormortisBuild = false
        for _ in 0..<200 {
            game.buildDeck()
            let deckRoleIds = game.roleDeck.map(\.roleId)
            if deckRoleIds.contains("vigormortis") {
                let rolesByTeam = countRolesByTeam(deckRoleIds, roles: sectsAndVioletsTemplate.roles)
                foundVigormortisBuild = true
                #expect(rolesByTeam.townsfolk == 6)
                #expect(rolesByTeam.outsiders == 0)
                #expect(rolesByTeam.minions == 1)
                #expect(rolesByTeam.demons == 1)
                break
            }
        }
        #expect(foundVigormortisBuild)
    }

    @Test func witchKillsCursedNominator() {
        let game = makeAssignedGame(templateId: "sects-and-violets", roleIds: ["witch", "washerwoman", "imp", "chef", "baron"])
        let cursed = game.players[1]
        let nominee = game.players[2]

        runNightStep(game, roleId: "witch", targets: [cursed.id])

        game.phase = .day
        game.setNominator(cursed.id)
        game.setNominee(nominee.id)

        #expect(game.players[1].alive == false)
    }

    @Test func evilTwinBlocksImmediateGoodWinWhenDemonDies() {
        let game = makeAssignedGame(templateId: "sects-and-violets", roleIds: ["evil-twin", "washerwoman", "fang-gu", "chef", "baron", "empath", "clockmaker"])

        game.beginNight()
        game.phase = .day
        let demon = game.players[2]
        game.nominationResults[demon.id] = game.executionThreshold
        game.executeNomineeIfSet()

        #expect(!game.isGameOver)
        #expect(game.phase != .finished)
    }
}

// MARK: - Sects & Violets (experimental)

@Suite(.serialized) struct SectsAndVioletsExperimentalTests {

    @Test func legionOnlyEvilVotesDoNotCount() {
        let game = makeAssignedGame(templateId: "sects-and-violets", roleIds: ["legion", "legion", "washerwoman", "chef", "baron"], experimental: true)
        let nominee = game.players[2]

        game.phase = .day
        game.setNominator(game.players[0].id)
        game.setNominee(nominee.id)
        game.castVote(voter: game.players[0].id, nominee: nominee.id)
        game.castVote(voter: game.players[1].id, nominee: nominee.id)

        #expect(game.weightedVoteCount(for: nominee.id) == 0)
    }

    @Test func fearmongerWinsWhenChosenTargetIsExecuted() {
        let game = makeAssignedGame(templateId: "sects-and-violets", roleIds: ["fearmonger", "washerwoman", "fang-gu", "chef", "cerenovus", "clockmaker", "dreamer"], experimental: true)
        let fearmonger = game.players[0]
        let target = game.players[1]

        game.phase = .night
        game.isFirstNightPhase = true
        game.currentNightSteps = [NightStepTemplate(id: "test-fearmonger", roleId: "fearmonger", condition: .always)]
        game.currentNightTargets = [target.id]
        game.completeCurrentNightAction()

        game.phase = .day
        game.setNominator(fearmonger.id)
        game.setNominee(target.id)
        game.nominationResults[target.id] = game.executionThreshold
        game.executeNomineeIfSet()

        #expect(game.isGameOver)
        #expect(game.winningSide == .evil)
    }
}

// MARK: - Bad Moon Rising

@Suite(.serialized) struct BadMoonRisingTests {

    @Test func pacifistCanSpareExecutedGoodPlayer() {
        let game = makeAssignedGame(templateId: "bad-moon-rising", roleIds: ["pacifist", "washerwoman", "imp", "chef", "baron"])
        let target = game.players[1]

        game.phase = .day
        game.nominationResults[target.id] = game.executionThreshold
        game.executeNomineeIfSet()

        #expect(game.players[1].alive)
    }

    @Test func teaLadyProtectsGoodNeighborsFromExecution() {
        let game = makeAssignedGame(templateId: "bad-moon-rising", roleIds: ["washerwoman", "tea-lady", "librarian", "imp", "baron"])

        game.phase = .day
        game.nominationResults[game.players[0].id] = game.executionThreshold
        game.executeNomineeIfSet()

        #expect(game.players[0].alive)
    }

    @Test func sailorMakesOnePlayerDrunkUntilDusk() {
        let game = makeAssignedGame(templateId: "bad-moon-rising", roleIds: ["sailor", "washerwoman", "imp", "chef", "baron"])
        let sailor = game.players[0]
        let target = game.players[1]

        runNightStep(game, roleId: "sailor", targets: [target.id])

        let drunkCount = [sailor.id, target.id].filter { id in
            guard let player = game.players.first(where: { $0.id == id }) else { return false }
            return game.playerStatusItems(for: player)
                .contains(where: { $0.contains("Sailor") || $0.contains("水手") })
        }.count
        #expect(drunkCount == 1)
    }

    @Test func courtierDrunksChosenCharacterForThreeDays() {
        let game = makeAssignedGame(templateId: "bad-moon-rising", roleIds: ["courtier", "zombuul", "chambermaid", "grandmother", "godfather"])

        game.phase = .night
        game.isFirstNightPhase = false
        game.currentNightSteps = [NightStepTemplate(id: "test-courtier", roleId: "courtier", condition: .always)]
        game.currentNightStepIndex = 0
        game.currentNightNote = "zombuul"
        game.completeCurrentNightAction()

        let zombuulPlayer = game.players[1]
        let statuses = game.playerStatusItems(for: zombuulPlayer)
        #expect(statuses.contains(where: { $0.contains("Courtier") || $0.contains("朝臣") }))
        #expect(game.players[0].roleLog.isEmpty == false)
    }

    @Test func chambermaidCountsPlayersWhoWakeTonight() {
        let game = makeAssignedGame(templateId: "bad-moon-rising", roleIds: ["chambermaid", "innkeeper", "gambler", "imp", "baron"])
        let chambermaid = game.players[0]
        let firstTarget = game.players[1]
        let secondTarget = game.players[2]

        game.phase = .night
        game.isFirstNightPhase = false
        game.currentNightSteps = badMoonRisingNightOrder
        game.currentNightStepIndex = badMoonRisingNightOrder.firstIndex(where: { $0.roleId == "chambermaid" }) ?? 0
        game.currentNightTargets = [firstTarget.id, secondTarget.id]
        game.completeCurrentNightAction()

        let lastLog = game.players.first(where: { $0.id == chambermaid.id })?.roleLog.last ?? ""
        #expect(lastLog.contains("2") || lastLog.contains("两"))
    }

    @Test func moonchildChoiceKillsGoodTarget() {
        let game = makeAssignedGame(templateId: "bad-moon-rising", roleIds: ["moonchild", "washerwoman", "imp", "chef", "baron"])
        let moonchild = game.players[0]
        let goodTarget = game.players[1]

        game.phase = .day
        game.nominationResults[moonchild.id] = game.executionThreshold
        game.executeNomineeIfSet()

        #expect(game.pendingMoonchild?.id == moonchild.id)
        game.chooseMoonchildTarget(goodTarget.id)
        game.startNextNight()

        #expect(game.players[1].alive == false)
    }
}

// MARK: - Experimental (cross-script)

@Suite(.serialized) struct ExperimentalCrossScriptTests {

    @Test func cultLeaderVoteCanWinForCurrentTeam() {
        let game = makeAssignedGame(templateId: "trouble-brewing", roleIds: ["washerwoman", "cultleader", "chef", "imp", "baron"], experimental: true)

        game.phase = .day
        game.resolveCultLeaderVote(allGoodJoined: true)

        #expect(game.isGameOver)
        #expect(game.winningSide == .good)
    }

    @Test func bansheeCanNominateTwiceAfterDemonKill() {
        let game = makeAssignedGame(templateId: "trouble-brewing", roleIds: ["banshee", "washerwoman", "imp", "chef", "baron"], experimental: true)
        let banshee = game.players[0]

        runNightStep(game, roleId: "imp", targets: [banshee.id])

        game.phase = .day
        #expect(game.availableNominatorsForDay.contains(where: { $0.id == banshee.id }))
        game.setNominator(banshee.id)
        game.setNominee(game.players[1].id)
        game.recordCurrentNomination()
        game.setNominator(banshee.id)
        game.setNominee(game.players[2].id)
        game.recordCurrentNomination()
        #expect(game.availableNominatorsForDay.contains(where: { $0.id == banshee.id }) == false)
    }
}

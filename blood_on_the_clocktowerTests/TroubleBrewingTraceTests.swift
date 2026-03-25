import Foundation
import Testing
@testable import blood_on_the_clocktower

@Suite(.serialized) struct TroubleBrewingTraceTests {

    /// Run 50 deterministic random game simulations for Trouble Brewing (no experimental roles).
    /// Each seed produces a fully reproducible game trace that exercises the complete flow:
    /// setup → first night → day (nominations, voting, execution/skip) → subsequent nights → game end.
    @Test(arguments: 1...50)
    func troubleBrewingRandomTrace(seed: Int) {
        var rng = LCG(seed: UInt64(seed))

        // Setup
        let game = ClocktowerGameViewModel()
        game.selectTemplate("trouble-brewing")
        game.setPlayerCount(5 + Int(rng.next() % 8)) // 5–12 players
        game.playerSetup()

        // Auto-assign displayed role for any Drunk cards before assignment
        for card in game.roleDeck where card.roleId == "drunk" && card.displayedRoleId == nil {
            let available = game.availableDrunkDisplayRoles(for: card.id)
            if let pick = available.randomElement(using: &rng) {
                game.selectDisplayedRoleForDrunkCard(card.id, roleId: pick.id)
            }
        }

        game.assignAllRandom()

        #expect(game.isAssignmentReady, "seed \(seed): assignment incomplete")
        #expect(game.players.count == game.playerCount, "seed \(seed): player count mismatch")

        // Verify deck composition
        let deckRoleIds = game.roleDeck.map(\.roleId)
        let allTBRoleIds = Set(troubleBrewingTemplate.roles.map(\.id))
        #expect(deckRoleIds.allSatisfy { allTBRoleIds.contains($0) }, "seed \(seed): deck contains non-TB role")

        // Run game
        game.beginNight()
        var steps = 0
        let maxSteps = 150

        while !game.isGameOver && steps < maxSteps {
            switch game.phase {
            case .firstNight, .night:
                stepNightPhase(game, seed: seed, rng: &rng)

            case .day:
                stepDayPhase(game, seed: seed, rng: &rng)

            case .finished:
                break

            default:
                break
            }

            assertCoreInvariants(game)
            assertAliveCountSanity(game, seed: seed)
            steps += 1
        }

        #expect(game.isGameOver || steps < maxSteps, "seed \(seed): simulation did not terminate in \(maxSteps) steps")

        if game.isGameOver {
            assertGameOverConsistency(game, seed: seed)
        }
    }
}

// MARK: - Night Phase Driver

private func stepNightPhase(
    _ game: ClocktowerGameViewModel,
    seed: Int,
    rng: inout LCG
) {
    // If waiting for Imp replacement selection, resolve it
    if game.isAwaitingImpReplacementSelection,
       let candidate = game.pendingImpReplacementCandidateIds.randomElement(using: &rng) {
        game.selectImpReplacement(candidate)
        return
    }

    guard game.currentNightActor != nil else {
        game.skipCurrentNightStep()
        return
    }

    game.clearNightSelection()
    let limit = game.currentNightTargetLimit()
    let candidates = game.currentNightCandidates().shuffled(using: &rng)
    for candidate in candidates.prefix(limit) {
        game.toggleNightTarget(candidate.id)
    }

    // Provide role-appropriate notes
    if let actor = game.currentNightActor {
        switch actor.roleId {
        case "fortuneteller", "empath", "chef", "washerwoman", "librarian", "investigator":
            game.currentNightNote = "trace seed \(seed)"
        case "courtier":
            game.currentNightNote = game.roleDeck.randomElement(using: &rng)?.roleId ?? "washerwoman"
        default:
            game.currentNightNote = "trace seed \(seed)"
        }
    }

    game.completeCurrentNightAction()
}

// MARK: - Day Phase Driver

private func stepDayPhase(
    _ game: ClocktowerGameViewModel,
    seed: Int,
    rng: inout LCG
) {
    // Handle pending moonchild
    if let moonchild = game.pendingMoonchild,
       let target = game.moonchildTargetCandidates
        .filter({ $0.id != moonchild.id })
        .randomElement(using: &rng) {
        game.chooseMoonchildTarget(target.id)
    }

    // Day abilities
    if game.canUseSlayerShot(),
       rng.nextBool(),
       let target = game.alivePlayers.randomElement(using: &rng) {
        game.chooseSlayerTarget(target.id)
        game.useSlayerShot()
        // If target was a Recluse, resolve the storyteller registration prompt
        if game.isAwaitingSlayerRecluseChoice {
            game.resolveSlayerRecluseRegistration(registersAsDemon: rng.nextBool())
        }
    }

    // Nomination rounds
    let nominationRounds = 1 + Int(rng.next() % 2)
    for _ in 0..<nominationRounds where game.phase == .day {
        guard let nominator = game.availableNominatorsForDay.randomElement(using: &rng) else { break }
        game.setNominator(nominator.id)

        let nominees = game.availableNomineesForDay.filter { $0.id != nominator.id }
        guard let nominee = nominees.randomElement(using: &rng) else { break }
        game.setNominee(nominee.id)

        // If nominee is a Virgin and nominator is a flexible registration player, resolve
        if game.isAwaitingVirginRegistrationChoice {
            game.resolvePendingVirginRegistration(registersAsTownsfolk: rng.nextBool())
        }

        guard let currentNominee = game.currentNominee, game.phase == .day else { continue }

        for voter in game.players.shuffled(using: &rng) {
            if rng.nextBool(), game.isVoteAllowed(voterId: voter.id, nominee: currentNominee.id) {
                game.castVote(voter: voter.id, nominee: currentNominee.id)
            }
        }

        if game.currentNominee != nil {
            game.recordCurrentNomination()
        }
    }

    // Resolve day
    guard game.phase == .day else { return }
    if !game.nominationResults.isEmpty, rng.nextBool() {
        game.executeNomineeIfSet()
    } else {
        game.endDayWithoutExecution()
    }
}

// MARK: - Game-Over Verification

private func assertGameOverConsistency(_ game: ClocktowerGameViewModel, seed: Int) {
    #expect(game.phase == .finished, "seed \(seed): gameOver but phase is not finished")
    #expect(game.winningSide != nil, "seed \(seed): gameOver but no winning side")

    if let reason = game.gameOverReason {
        switch reason {
        case .noDemonsAlive:
            #expect(game.winningSide == .good, "seed \(seed): noDemonsAlive should mean good wins")
        case .saintExecuted:
            #expect(game.winningSide == .evil, "seed \(seed): saintExecuted should mean evil wins")
        case .mayorSurvived:
            #expect(game.winningSide == .good, "seed \(seed): mayorSurvived should mean good wins")
        case .evilPopulationLead:
            #expect(game.winningSide == .evil, "seed \(seed): evilPopulationLead should mean evil wins")
        case .evilNoWinningPath:
            #expect(game.winningSide == .good, "seed \(seed): evilNoWinningPath should mean good wins")
        }
    }
}

/// Verify no impossible states in alive counts
private func assertAliveCountSanity(_ game: ClocktowerGameViewModel, seed: Int) {
    let aliveCount = game.alivePlayers.count
    let totalCount = game.players.count
    #expect(aliveCount >= 0 && aliveCount <= totalCount, "seed \(seed): impossible alive count \(aliveCount)/\(totalCount)")
}

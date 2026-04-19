import Foundation
import Testing
@testable import blood_on_the_clocktower

// MARK: - Script Template Helpers (loaded from JSON)

// swiftlint:disable force_unwrapping
let troubleBrewingTemplate: ScriptTemplate = ScriptDataLoader.loadBaseScripts().first(where: { $0.id == "trouble-brewing" })!
let badMoonRisingTemplate: ScriptTemplate = ScriptDataLoader.loadBaseScripts().first(where: { $0.id == "bad-moon-rising" })!
let sectsAndVioletsTemplate: ScriptTemplate = ScriptDataLoader.loadBaseScripts().first(where: { $0.id == "sects-and-violets" })!
// swiftlint:enable force_unwrapping
let badMoonRisingNightOrder: [NightStepTemplate] = badMoonRisingTemplate.nightOrderStandard

// MARK: - Game Factory

func makeAssignedGame(templateId: String, roleIds: [String], experimental: Bool = false) -> ClocktowerGameViewModel {
    let game = ClocktowerGameViewModel()
    game.selectTemplate(templateId)
    if experimental {
        game.setExperimentalEnabled(true, for: templateId)
    }
    game.playerCount = roleIds.count
    game.players = roleIds.enumerated().map { index, role in
        PlayerCard(
            id: UUID(),
            seatNumber: index + 1,
            name: "Player\(index + 1)",
            roleId: role,
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
    }
    game.roleDeck = roleIds.enumerated().map { index, roleId in
        RoleDeckCard(roleId: roleId, assignedPlayerId: game.players[index].id, state: .used)
    }
    return game
}

// MARK: - Night Action Helpers

/// Run a single night step for a given role. Sets up the step template, targets, optional note, and completes.
func runNightStep(
    _ game: ClocktowerGameViewModel,
    roleId: String,
    targets: [UUID] = [],
    note: String = "",
    firstNight: Bool = false
) {
    game.phase = firstNight ? .firstNight : .night
    game.isFirstNightPhase = firstNight
    game.currentNightSteps = [NightStepTemplate(id: "test-\(roleId)", roleId: roleId, condition: .always)]
    game.currentNightStepIndex = 0
    game.currentNightTargets = targets
    game.currentNightNote = note
    game.completeCurrentNightAction()
    // If this was the only night step, completeCurrentNightAction triggers
    // resolveNightDawn which starts a day timer. Invalidate it so it doesn't
    // leak into subsequent tests via the RunLoop.
    game.timer?.invalidate()
    game.timer = nil
}

// MARK: - Role Team Counting

struct RoleTeamCounts {
    let townsfolk: Int
    let outsiders: Int
    let minions: Int
    let demons: Int
}

func countRolesByTeam(_ roleIds: [String], roles: [RoleTemplate]) -> RoleTeamCounts {
    var townsfolk = 0
    var outsiders = 0
    var minions = 0
    var demons = 0

    for roleId in roleIds {
        let role = roles.first(where: { $0.id == roleId })
        guard let team = role?.team else { continue }
        switch team {
        case .townsfolk:
            townsfolk += 1
        case .outsider:
            outsiders += 1
        case .minion:
            minions += 1
        case .traveller:
            break
        case .demon:
            demons += 1
        }
    }

    return RoleTeamCounts(
        townsfolk: townsfolk,
        outsiders: outsiders,
        minions: minions,
        demons: demons
    )
}

// MARK: - Invariant Assertions

func assertCoreInvariants(_ game: ClocktowerGameViewModel) {
    let playerIds = Set(game.players.map(\.id))
    #expect(playerIds.count == game.players.count)
    #expect(game.votesByVoter.keys.allSatisfy { playerIds.contains($0) })
    #expect(game.votesByVoter.values.allSatisfy { playerIds.contains($0) })

    if game.phase != .assignment && !game.players.isEmpty {
        #expect(game.players.allSatisfy { $0.roleId != nil })
    }

    if game.isGameOver {
        #expect(game.phase == .finished)
    }
}

// MARK: - Deterministic RNG

struct LCG: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed == 0 ? 0x4d595df4d0f33173 : seed
    }

    mutating func next() -> UInt64 {
        state = 6364136223846793005 &* state &+ 1442695040888963407
        return state
    }

    mutating func nextBool() -> Bool {
        (next() & 1) == 0
    }
}

// MARK: - ViewModel Test Extensions

extension ClocktowerGameViewModel {
    func updateButlerMaster(_ butlerID: UUID, _ masterID: UUID) {
        guard let index = players.firstIndex(where: { $0.id == butlerID }) else { return }
        players[index].butlerMasterId = masterID
    }
}

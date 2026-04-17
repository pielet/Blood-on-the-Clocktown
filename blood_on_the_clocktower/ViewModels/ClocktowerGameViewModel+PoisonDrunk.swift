import Foundation

extension ClocktowerGameViewModel {

    // MARK: - Dusk Expiration

    func expireDuskLimitedEffects() {
        poisonerPoisonedPlayerId = nil
        poisonerPoisonSourcePlayerId = nil
        temporaryDrunkPlayerUntilDayNumbers = temporaryDrunkPlayerUntilDayNumbers.filter { $0.value > currentDayNumber }
        temporaryDrunkPlayerSources = temporaryDrunkPlayerSources.filter { playerId, _ in
            (temporaryDrunkPlayerUntilDayNumbers[playerId] ?? -1) > currentDayNumber
        }
        temporaryDrunkRoleUntilDayNumbers = temporaryDrunkRoleUntilDayNumbers.filter { $0.value > currentDayNumber }
        temporaryDrunkRoleSources = temporaryDrunkRoleSources.filter { roleId, _ in
            (temporaryDrunkRoleUntilDayNumbers[roleId] ?? -1) > currentDayNumber
        }
        if let minstrelDrunkUntilDayNumber, minstrelDrunkUntilDayNumber <= currentDayNumber {
            self.minstrelDrunkUntilDayNumber = nil
        }
    }

    // MARK: - Temporary Drunk

    func setTemporaryDrunk(playerId: UUID, untilDayNumber: Int, source: String) {
        temporaryDrunkPlayerUntilDayNumbers[playerId] = untilDayNumber
        temporaryDrunkPlayerSources[playerId] = source
    }

    func setTemporaryDrunk(roleId: String, untilDayNumber: Int, source: String) {
        temporaryDrunkRoleUntilDayNumbers[roleId] = untilDayNumber
        temporaryDrunkRoleSources[roleId] = source
    }

    // MARK: - Ability Suppression

    func isAbilitySuppressed(_ player: PlayerCard) -> Bool {
        if playerIsPoisonedOrDrunk(player) {
            return true
        }
        if isSuppressedByPreacher(player) {
            return true
        }
        return false
    }

    // MARK: - Poison / Drunk Queries

    func isPlayerPoisonedOrDrunk(_ player: PlayerCard) -> Bool {
        playerIsPoisonedOrDrunk(player)
    }

    func isPlayerExternallyPoisonedOrDrunk(_ player: PlayerCard) -> Bool {
        playerIsPoisoned(player) || playerIsExternallyDrunk(player)
    }

    func playerIsPoisonedOrDrunk(_ player: PlayerCard) -> Bool {
        if player.roleId == "drunk" { return true }
        if playerIsPoisoned(player) { return true }
        if playerIsExternallyDrunk(player) { return true }
        return false
    }

    func playerIsPoisoned(_ player: PlayerCard) -> Bool {
        if player.poisonedTonight {
            return true
        }
        if poisonerPoisonIsActive(on: player) {
            return true
        }
        if let widowPoisonedPlayerId,
           widowPoisonedPlayerId == player.id,
           players.contains(where: { $0.alive && $0.roleId == "widow" }) {
            return true
        }
        if let lleechHostPlayerId,
           lleechHostPlayerId == player.id,
           players.contains(where: { $0.alive && $0.roleId == "lleech" }) {
            return true
        }
        if let pukkaPoisonedPlayerId,
           pukkaPoisonedPlayerId == player.id,
           players.contains(where: { $0.alive && $0.roleId == "pukka" }) {
            return true
        }
        if noDashiiPoisonedPlayerIds.contains(player.id),
           players.contains(where: { $0.alive && $0.roleId == "no-dashii" }) {
            return true
        }
        if vigormortisPoisonedNeighborIds.contains(player.id),
           players.contains(where: { $0.alive && $0.roleId == "vigormortis" }) {
            return true
        }
        if let xaanPoisonedUntilDayNumber,
           currentDayNumber <= xaanPoisonedUntilDayNumber,
           roleTemplate(for: player.roleId ?? "")?.team == .townsfolk,
           players.contains(where: { $0.alive && $0.roleId == "xaan" }) {
            return true
        }
        return false
    }

    func poisonerPoisonIsActive(on player: PlayerCard) -> Bool {
        guard let poisonerPoisonedPlayerId,
              poisonerPoisonedPlayerId == player.id else {
            return false
        }
        if let poisonerPoisonSourcePlayerId {
            return players.contains { $0.id == poisonerPoisonSourcePlayerId && $0.alive }
        }
        return players.contains { $0.alive && $0.roleId == "poisoner" }
    }

    func playerIsExternallyDrunk(_ player: PlayerCard) -> Bool {
        if let minstrelDrunkUntilDayNumber,
           currentDayNumber <= minstrelDrunkUntilDayNumber,
           player.roleId != "minstrel",
           isPlayerGood(player) {
            return true
        }
        if let sweetheartDrunkPlayerId,
           sweetheartDrunkPlayerId == player.id {
            return true
        }
        if let untilDayNumber = temporaryDrunkPlayerUntilDayNumbers[player.id],
           untilDayNumber >= currentDayNumber {
            return true
        }
        if let roleId = player.roleId,
           let untilDayNumber = temporaryDrunkRoleUntilDayNumbers[roleId],
           untilDayNumber >= currentDayNumber {
            return true
        }
        return false
    }
}

import Foundation

extension ClocktowerGameViewModel {

    // MARK: - Immediate Night Kill Resolution

    /// Resolves the primary demon kill immediately, checking global blockers and protections.
    /// Returns `true` if the target was actually killed.
    @discardableResult
    func resolveDemonKill(_ target: UUID) -> Bool {
        if hasLeviathanInPlay {
            addLog("Leviathan is in play. No Demon kill occurs tonight.", "利维坦在场，今夜不会发生恶魔击杀。")
            return false
        }
        if princessProtectedNightAfterDay == currentDayNumber {
            addLog("Princess prevented the Demon from killing tonight.", "公主阻止了恶魔今夜杀人。")
            return false
        }
        if let exorcisedPlayerId,
           let exorcisedPlayer = players.first(where: { $0.id == exorcisedPlayerId }) {
            addLog("The Exorcist prevented \(exorcisedPlayer.name) from waking tonight.", "驱魔人阻止了 \(exorcisedPlayer.name) 今夜醒来。")
            return false
        }
        if demonKillBlockedTonight {
            if let targetPlayer = playerLookup(by: target) {
                addLog("The Demon's kill on \(targetPlayer.name) was blocked by the Lycanthrope.", "\(targetPlayer.name) 受到狼人的影响，恶魔今夜未能击杀。")
            } else {
                addLog("The Demon did not kill tonight because of the Lycanthrope.", "由于狼人的效果，恶魔今夜没有击杀。")
            }
            return false
        }
        return resolveForcedDemonKill(target)
    }

    /// Resolves a forced demon kill (Shabaloth, Po) with protection checks but no global blockers.
    @discardableResult
    func resolveForcedDemonKill(_ target: UUID) -> Bool {
        guard let targetPlayer = playerLookup(by: target), targetPlayer.alive else { return false }
        if protectedTonight.contains(target) || demonProtectedTonight.contains(target) {
            addLog("Night kill on \(targetPlayer.name) was prevented by night protection.", "\(targetPlayer.name) 的夜杀被夜间保护抵消了。")
            return false
        }
        if targetPlayer.roleId == "soldier", !isAbilitySuppressed(targetPlayer) {
            addLog("Night kill on \(targetPlayer.name) was blocked by Soldier.", "\(targetPlayer.name) 的夜杀被士兵能力抵消了。")
            return false
        }
        killByDemonIfAlive(target, reason: ui("Killed by night action", "夜间技能击杀"))
        return true
    }

    /// Resolves a forced non-demon night kill (Godfather) with general protection only.
    func resolveForcedNightKill(_ target: UUID) {
        guard let targetPlayer = playerLookup(by: target), targetPlayer.alive else { return }
        if protectedTonight.contains(target) {
            addLog("Night kill on \(targetPlayer.name) was prevented by night protection.", "\(targetPlayer.name) 的夜杀被夜间保护抵消了。")
            return
        }
        killIfAlive(target, reason: ui("Killed by night action", "夜间技能击杀"))
    }

    // MARK: - Player State Modifiers

    func setPoisoned(_ playerID: UUID, _ poisoned: Bool) {
        markPlayer(playerID) { p in
            p.poisonedTonight = poisoned
            if poisoned { p.roleLog.append(ui("Poisoned tonight.", "今夜中毒。")) }
        }
    }

    func setProtected(_ playerID: UUID, _ protected: Bool, source: String) {
        if protected {
            if source == "monk" {
                demonProtectedTonight.insert(playerID)
            } else {
                protectedTonight.insert(playerID)
            }
        }
        markPlayer(playerID) { p in
            p.protectedTonight = protected
            if protected {
                switch source {
                case "innkeeper":
                    p.roleLog.append(ui("Protected this night by the Innkeeper.", "今夜受到店主保护。"))
                default:
                    p.roleLog.append(ui("Protected this night by the Monk.", "今夜受到僧侣保护。"))
                }
            }
        }
    }

    func setButlerMaster(_ actorID: UUID, master: UUID) {
        markPlayer(actorID) { p in
            p.butlerMasterId = master
            p.wasButlerTonight = true
        }
        markPlayer(master) { p in
            p.roleLog.append(ui("Was chosen as the Butler's master.", "被选为管家的主人。"))
        }
    }

    func applyVoteModifier(_ playerID: UUID, delta: Int) {
        markPlayer(playerID) { p in
            let current = p.voteModifier == 0 ? 1 : p.voteModifier
            var next = max(-6, min(6, current + delta))
            if current > 0 && next == 0 && delta < 0 {
                next = -1
            }
            p.voteModifier = next
            p.roleLog.append(ui("Vote modifier changed by \(delta).", "投票修正值变化 \(delta)。"))
        }
    }

    // MARK: - Protection Checks

    func canWakeAtNight(_ player: PlayerCard) -> Bool {
        player.alive || vigormortisEmpoweredMinionIds.contains(player.id)
    }

    func isProtectedByTeaLady(_ playerId: UUID) -> Bool {
        for teaLady in players where teaLady.alive && teaLady.roleId == "tea-lady" && !isAbilitySuppressed(teaLady) {
            let neighbors = aliveNeighbors(of: teaLady)
            guard neighbors.count == 2 else { continue }
            guard neighbors.allSatisfy({ isPlayerGood($0) }) else { continue }
            if neighbors.contains(where: { $0.id == playerId }) {
                return true
            }
        }
        return false
    }

    func shouldPacifistSave(_ player: PlayerCard, reason: String) -> Bool {
        guard reason == "Executed" || reason == "处决",
              isPlayerGood(player),
              !pacifistSavedPlayerIds.contains(player.id),
              players.contains(where: { $0.alive && $0.roleId == "pacifist" && !isAbilitySuppressed($0) }) else {
            return false
        }
        pacifistSavedPlayerIds.insert(player.id)
        addLog(
            "Pacifist spared \(player.name) from execution death.",
            "和平主义者让 \(player.name) 免于处决死亡。"
        )
        return true
    }

    // MARK: - Death Resolution

    func killIfAlive(_ playerId: UUID, reason: String) {
        guard let index = players.firstIndex(where: { $0.id == playerId }), players[index].alive else { return }
        if players[index].roleId == "sailor",
           !isAbilitySuppressed(players[index]) {
            addLog(
                "\(players[index].name) survived because the Sailor cannot die while sober.",
                "\(players[index].name) 因水手在清醒时无法死亡而存活。"
            )
            return
        }
        if reason != "Assassin attack",
           reason != "刺客击杀",
           isProtectedByTeaLady(playerId) {
            addLog(
                "\(players[index].name) was protected from death by the Tea Lady.",
                "\(players[index].name) 受茶夫人保护，没有死亡。"
            )
            return
        }
        if shouldPacifistSave(players[index], reason: reason) {
            return
        }
        if players[index].roleId == "fool",
           !foolSpentPlayerIds.contains(playerId),
           !isAbilitySuppressed(players[index]) {
            foolSpentPlayerIds.insert(playerId)
            players[index].roleLog.append(ui("Survived the first death as the Fool.", "以愚者身份免除了第一次死亡。"))
            addLog("\(players[index].name) survived the first death as the Fool.", "\(players[index].name) 以愚者身份免除了第一次死亡。")
            return
        }
        if players[index].roleId == "zombuul",
           !zombuulSpentPlayerIds.contains(playerId),
           !isAbilitySuppressed(players[index]) {
            zombuulSpentPlayerIds.insert(playerId)
            players[index].roleLog.append(ui("Survived the first death as the Zombuul.", "以僵怖身份免除了第一次死亡。"))
            addLog(
                "\(players[index].name) survived the first death as the Zombuul.",
                "\(players[index].name) 以僵怖身份免除了第一次死亡。"
            )
            return
        }
        if players[index].roleId == "lleech",
           let hostId = lleechHostPlayerId,
           players.contains(where: { $0.id == hostId && $0.alive }) {
            addLog("\(players[index].name) survived because the Lleech host is still alive.", "\(players[index].name) 因利奇宿主仍存活而没有死亡。")
            return
        }
        let aliveCountBeforeDeath = players.filter(\.alive).count
        let deadRoleId = players[index].roleId
        players[index].alive = false
        players[index].deadReason = reason
        players[index].isDeadTonight = phase == .night || phase == .firstNight
        players[index].roleLog.append(ui("Died: \(reason)", "死亡：\(reason)"))
        deadTonight.insert(playerId)
        if phase == .day {
            didDeathOccurToday = true
        }

        resolveFarmerDeathIfNeeded(players[index])

        if players[index].roleId == "moonchild",
           reason == "Executed" || reason == "处决" {
            moonchildPendingPlayerId = playerId
            moonchildPendingTargetId = nil
        }

        if players[index].roleId == "sweetheart", sweetheartDrunkPlayerId == nil {
            let candidates = players.filter { $0.id != playerId }
            sweetheartDrunkPlayerId = candidates.randomElement()?.id
            if let drunkId = sweetheartDrunkPlayerId, let drunkName = playerName(drunkId) {
                addLog("Sweetheart died. \(drunkName) is now drunk.", "甜心死亡。\(drunkName) 现在醉酒。")
            }
        }

        if reason == "Executed" || reason == "处决",
           roleTemplate(for: deadRoleId ?? "")?.team == .minion,
           players.contains(where: { $0.alive && $0.roleId == "minstrel" && !isAbilitySuppressed($0) }) {
            minstrelDrunkUntilDayNumber = currentDayNumber + 1
            addLog(
                "A Minion was executed. All good players are drunk until tomorrow dusk.",
                "有爪牙被处决。所有善良玩家将醉酒直到明天黄昏。"
            )
        }

        if reason == "Executed" || reason == "处决",
           playerId == evilTwinGoodPlayerId,
           evilTwinPlayerId != nil,
           players.contains(where: { $0.id == evilTwinPlayerId && $0.alive }) {
            addLog(
                "The good twin died while the Evil Twin lives. Evil wins.",
                "善良双子死亡而邪恶双子仍存活。邪恶阵营获胜。"
            )
            setGameOver(reason: .evilPopulationLead, side: .evil)
            return
        }

        if playerId == lleechHostPlayerId,
           let lleech = players.first(where: { $0.alive && $0.roleId == "lleech" }) {
            killIfAlive(lleech.id, reason: ui("Lleech host died", "利奇宿主死亡"))
        }

        if roleTemplate(for: deadRoleId ?? "")?.team == .demon {
            if deadRoleId == "imp" {
                players[index].roleLog.append(ui("Died as the Imp.", "以小恶魔身份死亡。"))
            }

            if phase == .day {
                resolveDaytimeDemonDeath(deadRoleId: deadRoleId, aliveCountBeforeDeath: aliveCountBeforeDeath, reason: reason)
                return
            }

            if deadRoleId == "imp" {
                impDiedTonight = true
            } else {
                gameOverCheck()
            }
            return
        }

        if (reason == "Executed" || reason == "处决") && players[index].roleId == "saint" && !isAbilitySuppressed(players[index]) {
            setGameOver(reason: .saintExecuted, side: .evil)
            return
        }
        gameOverCheck()
    }

    func killByDemonIfAlive(_ playerId: UUID, reason: String) {
        let wasAlive = playerLookup(by: playerId)?.alive == true
        let deadRoleId = playerLookup(by: playerId)?.roleId
        killIfAlive(playerId, reason: reason)
        if wasAlive, playerLookup(by: playerId)?.alive == false {
            demonKilledTonight.insert(playerId)
            resolveGrandmotherDeathIfNeeded(grandchildId: playerId)
            if deadRoleId == "banshee" {
                activateBanshee(playerId)
            }
            if deadRoleId == "king" {
                kingKilledByDemonPlayerId = playerId
            }
        }
    }

    func resolveDaytimeDemonDeath(deadRoleId: String?, aliveCountBeforeDeath: Int, reason: String) {
        guard let deadRoleId else {
            gameOverCheck()
            return
        }

        if aliveCountBeforeDeath >= 5,
           let scarletIndex = players.firstIndex(where: { $0.alive && $0.roleId == "scarletwoman" }) {
            let oldRole = localizedRoleName(roleTemplate(for: players[scarletIndex].roleId ?? ""))
            let newRole = localizedRoleName(roleTemplate(for: deadRoleId))
            players[scarletIndex].roleId = deadRoleId
            players[scarletIndex].becameDemonTonight = true
            players[scarletIndex].roleLog.append(ui("Became the Demon.", "转变为恶魔。"))
            players[scarletIndex].roleLog.append(ui("Replacement selected after the Demon died.", "在恶魔死亡后被选为替代恶魔。"))
            addLog("\(oldRole) became the new \(newRole).", "\(oldRole) 转变为了新的 \(newRole)。")
            return
        }

        if reason == "Executed" || reason == "处决",
           players.contains(where: { $0.alive && $0.roleId == "mastermind" && !isAbilitySuppressed($0) }) {
            mastermindExtraDayActive = true
            addLog("The Demon died by execution, but Mastermind keeps the game going for 1 more day.", "恶魔被处决死亡，但主谋让游戏继续 1 天。")
            return
        }

        gameOverCheck()
    }

    // MARK: - Death-triggered Effects

    func activateBanshee(_ playerId: UUID) {
        guard let player = playerLookup(by: playerId) else { return }
        bansheeEmpoweredPlayerIds.insert(player.id)
        markPlayer(player.id) { target in
            target.voteModifier = 2
            target.roleLog.append(ui("The Demon killed you. You may nominate twice per day and vote twice per nomination.", "你被恶魔杀死。你现在每天可提名两次，且每轮提名可投两票。"))
        }
        addLog(
            ui("All players learn that \(player.name) was the Banshee and is now empowered.", "所有玩家得知 \(player.name) 是女妖，且其已获得强化能力。")
        )
    }

    func resolveFarmerDeathIfNeeded(_ deadPlayer: PlayerCard) {
        guard deadPlayer.roleId == "farmer",
              phase == .night || phase == .firstNight else {
            return
        }
        let eligible = players.filter { $0.alive && isPlayerGood($0) && $0.id != deadPlayer.id }
        guard let chosen = eligible.randomElement() else { return }
        markPlayer(chosen.id) { player in
            player.roleId = "farmer"
            player.roleLog.append(ui("Became the Farmer.", "成为了农夫。"))
        }
        addLog(
            ui("Farmer \(deadPlayer.name) died at night. \(chosen.name) became the Farmer.", "农夫 \(deadPlayer.name) 夜间死亡。\(chosen.name) 成为了新的农夫。")
        )
    }

    func resolveGrandmotherDeathIfNeeded(grandchildId: UUID) {
        let linkedGrandmothers = grandmotherLinkedPlayerIds
            .filter { $0.value == grandchildId }
            .map(\.key)

        for grandmotherId in linkedGrandmothers {
            guard let grandmother = playerLookup(by: grandmotherId), grandmother.alive else { continue }
            killIfAlive(grandmotherId, reason: ui("Grandmother grief", "祖母悲痛而亡"))
            addLog(
                ui("\(grandmother.name) died because their Grandmother target was killed by the Demon.", "\(grandmother.name) 因其祖母目标被恶魔杀死而悲痛死亡。")
            )
        }
    }
}

import Foundation
import SwiftUI

extension ClocktowerGameViewModel {

    // MARK: - Day flow and voting

    var alivePlayers: [PlayerCard] {
        players.filter(\.alive)
    }

    var availableNominatorsForDay: [PlayerCard] {
        players.filter { canNominateDuringDay($0) }
    }

    var availableNomineesForDay: [PlayerCard] {
        if isRiotDay {
            return alivePlayers
        }
        let lockedNomineeIds = Set(nominationResults.keys)
        return alivePlayers.filter { !lockedNomineeIds.contains($0.id) }
    }

    var eligibleVoters: [PlayerCard] {
        players.filter { canParticipateInCurrentVote(voterId: $0.id) }
    }

    var currentNominee: PlayerCard? {
        guard let nomineeID else { return nil }
        return players.first(where: { $0.id == nomineeID })
    }

    var currentNominator: PlayerCard? {
        guard let nominatorID else { return nil }
        return players.first(where: { $0.id == nominatorID })
    }

    func canNominateDuringDay(_ player: PlayerCard) -> Bool {
        if player.alive {
            return true
        }
        guard bansheeEmpoweredPlayerIds.contains(player.id) else { return false }
        return (bansheeNominationsUsedByDay[player.id] ?? 0) < 2
    }

    func canParticipateInCurrentVote(voterId: UUID) -> Bool {
        guard let voter = players.first(where: { $0.id == voterId }) else { return false }
        if voter.alive {
            return true
        }
        if bansheeEmpoweredPlayerIds.contains(voter.id) {
            return true
        }
        return voter.ghostVoteAvailable || votesByVoter[voter.id] != nil
    }

    func playerVoteStatusText(for player: PlayerCard) -> String {
        if bansheeEmpoweredPlayerIds.contains(player.id) {
            let nominationsLeft = max(0, 2 - (bansheeNominationsUsedByDay[player.id] ?? 0))
            return ui("Dead Banshee: 2 votes per nomination, \(nominationsLeft) nominations left today", "死亡女妖：每轮 2 票，今日剩余 \(nominationsLeft) 次提名")
        }
        return player.ghostVoteAvailable
            ? ui("Dead, 1 dead vote available", "死亡，可用 1 次幽灵票")
            : ui("Dead, dead vote spent", "死亡，幽灵票已用尽")
    }

    func castVote(voter: UUID, nominee: UUID?) {
        guard canParticipateInCurrentVote(voterId: voter) else { return }
        guard isVoteAllowed(voterId: voter, nominee: nominee) else { return }
        if let nominee = nominee {
            votesByVoter[voter] = nominee
        } else {
            votesByVoter.removeValue(forKey: voter)
        }
        reconcileButlerVotes(forMasterId: voter)
    }

    func setNominator(_ nominator: UUID?) {
        if let nominator,
           let player = playerLookup(by: nominator),
           !canNominateDuringDay(player) {
            return
        }
        nominatorID = nominator
        nomineeID = nil
        pendingVirginRegistrationNominatorId = nil
        votesByVoter.removeAll()
    }

    func voteCount(for nominee: UUID?) -> Int {
        guard let nominee else { return 0 }
        let eligibleVotes = votesByVoter
            .filter { $0.value == nominee }
            .filter { isVoteAllowed(voterId: $0.key, nominee: nominee) }
        if hasLegionInPlay,
           !eligibleVotes.isEmpty,
           eligibleVotes.keys.compactMap({ playerLookup(by: $0) }).allSatisfy({ isPlayerEvil($0) }) {
            return 0
        }
        return eligibleVotes.count
    }

    func weightedVoteCount(for nominee: UUID?) -> Int {
        guard let nominee else { return 0 }
        let eligibleVotes = votesByVoter
            .filter { $0.value == nominee }
            .compactMap { pair -> (UUID, Int)? in
                guard let player = playerLookup(by: pair.key) else { return nil }
                guard canParticipateInCurrentVote(voterId: pair.key) else { return nil }
                guard isVoteAllowed(voterId: pair.key, nominee: nominee) else { return nil }
                return (pair.key, player.voteModifier == 0 ? 1 : player.voteModifier)
            }
        if hasLegionInPlay,
           !eligibleVotes.isEmpty,
           eligibleVotes.compactMap({ playerLookup(by: $0.0) }).allSatisfy({ isPlayerEvil($0) }) {
            return 0
        }
        return eligibleVotes.map(\.1).reduce(0, +)
    }

    func setNominee(_ nominee: UUID?) {
        if isRiotDay, let nominee {
            resolveRiotNomination(nominee)
            return
        }
        guard nominatorID != nil || nominee == nil else { return }
        nomineeID = nominee
        pendingVirginRegistrationNominatorId = nil
        votesByVoter.removeAll()
        if let nominatorID, let nominee {
            resolveNominationStart(nominatorId: nominatorID, nomineeId: nominee)
        }
        if needsVirginRegistrationChoice(for: nominee, nominatorId: nominatorID) {
            pendingVirginRegistrationNominatorId = nominatorID
            return
        }
        maybeProcessVirginNomination(nominee)
    }

    var votedCandidates: [PlayerCard] {
        let nomineeIds = Set(nominationResults.keys)
        return players
            .filter { nomineeIds.contains($0.id) }
            .sorted { (nominationResults[$0.id] ?? 0) > (nominationResults[$1.id] ?? 0) }
    }

    var leadingExecutionCandidate: PlayerCard? {
        let candidates = votedCandidates
        guard let first = candidates.first else { return nil }
        let topVotes = nominationResults[first.id] ?? 0
        guard topVotes > 0 else { return nil }
        guard topVotes >= executionThreshold else { return nil }
        let tiedTopCount = candidates.filter { (nominationResults[$0.id] ?? 0) == topVotes }.count
        return tiedTopCount == 1 ? first : nil
    }

    var isExecutionTied: Bool {
        let candidates = votedCandidates
        guard let first = candidates.first else { return false }
        let topVotes = nominationResults[first.id] ?? 0
        guard topVotes > 0 else { return false }
        return candidates.filter { (nominationResults[$0.id] ?? 0) == topVotes }.count > 1
    }

    var executionThreshold: Int {
        max(1, Int(ceil(Double(alivePlayers.count) / 2.0)))
    }

    func lockedVoteCount(for nominee: UUID) -> Int {
        nominationResults[nominee] ?? 0
    }

    func recordCurrentNomination() {
        guard let nomineeID else { return }
        let count = weightedVoteCount(for: nomineeID)
        nominationResults[nomineeID] = count
        if let nominatorID {
            nominationNominatorByNominee[nomineeID] = nominatorID
            if bansheeEmpoweredPlayerIds.contains(nominatorID),
               let nominator = playerLookup(by: nominatorID),
               !nominator.alive {
                bansheeNominationsUsedByDay[nominatorID, default: 0] += 1
            }
        }
        for (voterId, _) in votesByVoter {
            if let voter = playerLookup(by: voterId), roleTemplate(for: voter.roleId ?? "")?.team == .demon {
                demonVotedTodayFlag = true
            }
        }

        let deadVoters = votesByVoter.keys.compactMap { voterId -> UUID? in
            guard let voter = players.first(where: { $0.id == voterId }),
                  !voter.alive,
                  voter.ghostVoteAvailable,
                  !bansheeEmpoweredPlayerIds.contains(voter.id) else {
                return nil
            }
            return voter.id
        }

        for voterID in deadVoters {
            markPlayer(voterID) { player in
                player.ghostVoteAvailable = false
                player.roleLog.append(ui("Spent the dead vote during day voting.", "在白天投票中用掉了幽灵票。"))
            }
        }

        let nomineeName = playerName(nomineeID) ?? ui("Unknown", "未知")
        addLog("Nomination recorded: \(nomineeName) received \(count) vote(s).", "已锁定提名结果：\(nomineeName) 获得 \(count) 票。")
        self.nominatorID = nil
        self.nomineeID = nil
        pendingVirginRegistrationNominatorId = nil
        votesByVoter.removeAll()
    }

    func clearCurrentNomination() {
        nominatorID = nil
        nomineeID = nil
        pendingVirginRegistrationNominatorId = nil
        votesByVoter.removeAll()
    }

    func setGoblinClaimed(_ claimed: Bool, for playerId: UUID) {
        goblinClaimedPlayerId = claimed ? playerId : nil
    }

    func resolveNominationStart(nominatorId: UUID, nomineeId: UUID) {
        guard let nominator = playerLookup(by: nominatorId),
              let nominee = playerLookup(by: nomineeId) else { return }

        if roleTemplate(for: nominator.roleId ?? "")?.team == .minion {
            minionNominatedTodayFlag = true
        }

        if witchCursedPlayerId == nominatorId,
           alivePlayers.count > 3 {
            killIfAlive(nominatorId, reason: ui("Witch curse", "女巫诅咒"))
            addLog("\(nominator.name) nominated and died to the Witch curse.", "\(nominator.name) 发起提名后死于女巫诅咒。")
            witchCursedPlayerId = nil
        }

        addLog("\(nominator.name) nominated \(nominee.name).", "\(nominator.name) 提名了 \(nominee.name)。")
    }

    func resolveRiotNomination(_ nomineeId: UUID) {
        guard let nominee = players.first(where: { $0.id == nomineeId && $0.alive }) else { return }
        killIfAlive(nomineeId, reason: ui("Executed", "处决"))
        if players.contains(where: { $0.id == nomineeId && $0.alive }) {
            addLog("Riot nomination: \(nominee.name) survived the execution.", "暴乱提名：\(nominee.name) 在处决中存活。")
        } else {
            addLog("Riot nomination: \(nominee.name) died immediately.", "暴乱提名：\(nominee.name) 被立即处决。")
        }

        let aliveRiotCount = players.filter { $0.alive && $0.roleId == "riot" }.count
        if aliveRiotCount == 0 {
            addLog("All Riot players are dead. Good wins.", "所有暴乱玩家均已死亡。善良阵营获胜。")
            setGameOver(reason: .noDemonsAlive, side: .good)
            return
        }

        let aliveCount = players.filter(\.alive).count
        if aliveCount <= 2 {
            addLog("Riot reached the final 2 players. Evil wins.", "暴乱推进至仅剩 2 名存活玩家。邪恶阵营获胜。")
            setGameOver(reason: .evilPopulationLead, side: .evil)
            return
        }
    }

    func chooseSlayerTarget(_ playerId: UUID?) {
        guard let playerId else {
            slayerSelectedTarget = nil
            return
        }
        slayerSelectedTarget = playerId
    }

    var isAwaitingSlayerRecluseChoice: Bool {
        pendingSlayerRecluseTargetId != nil
    }

    var pendingSlayerReclusePlayer: PlayerCard? {
        guard let pendingSlayerRecluseTargetId else { return nil }
        return playerLookup(by: pendingSlayerRecluseTargetId)
    }

    func resolveSlayerRecluseRegistration(registersAsDemon: Bool) {
        pendingSlayerRecluseTargetId = nil
        executeSlayerShot(recluseRegisterAsDemon: registersAsDemon)
    }

    func useSlayerShot() {
        guard let shooter = currentSlayer() else { return }
        guard !shooter.slayerShotUsed else { return }
        guard let targetId = slayerSelectedTarget else { return }
        guard let target = players.first(where: { $0.id == targetId }) else { return }

        // If target is a Recluse and the Slayer isn't suppressed/fake, prompt the storyteller
        if target.roleId == "recluse",
           !isDisplayedDrunk(shooter, actingAs: "slayer"),
           !isAbilitySuppressed(shooter) {
            pendingSlayerRecluseTargetId = targetId
            return
        }

        executeSlayerShot(recluseRegisterAsDemon: false)
    }

    func executeSlayerShot(recluseRegisterAsDemon: Bool) {
        guard let shooter = currentSlayer() else { return }
        guard !shooter.slayerShotUsed else { return }
        guard let targetId = slayerSelectedTarget else { return }
        guard let target = players.first(where: { $0.id == targetId }) else { return }
        let isFakeSlayer = isDisplayedDrunk(shooter, actingAs: "slayer")
        let targetWasAlive = target.alive
        let targetIsDemon = roleTemplate(for: target.roleId ?? "")?.team == .demon
        let targetRegistersAsDemon = targetIsDemon || (target.roleId == "recluse" && recluseRegisterAsDemon)

        markPlayer(shooter.id) { p in
            p.slayerShotUsed = true
        }

        if isFakeSlayer {
            markPlayer(shooter.id) { p in
                p.roleLog.append("Actually the Drunk. Used a fake Slayer shot on \(target.name).")
            }
            addLog(
                "\(shooter.name) is actually the Drunk. A fake Slayer shot was used on \(target.name) with no real effect.",
                "\(shooter.name) 的真实身份是酒鬼。其对 \(target.name) 使用了一次假的猎手射击，没有真实效果。",
                toneOverride: .drunk
            )
            slayerSelectedTarget = nil
            return
        }

        if isAbilitySuppressed(shooter) {
            addLog(
                "\(shooter.name) used the Slayer shot on \(target.name), but it had no effect because the Slayer was poisoned.",
                "\(shooter.name) 对 \(target.name) 发动了猎手技能，但由于猎手已中毒，没有产生效果。"
            )
            markPlayer(shooter.id) { p in
                p.roleLog.append("Used the Slayer shot on \(target.name) unsuccessfully.")
            }
            slayerSelectedTarget = nil
            return
        }

        if targetWasAlive && targetRegistersAsDemon {
            killIfAlive(target.id, reason: "Slayer shot")
            if target.roleId == "recluse" {
                addLog(
                    "\(shooter.name) used the Slayer shot on \(target.name). The Recluse registered as the Demon and died.",
                    "\(shooter.name) 对 \(target.name) 发动猎手技能。隐士登记为恶魔并死亡。"
                )
            } else {
                addLog(
                    "\(shooter.name) used the Slayer shot on \(target.name) and killed the Demon.",
                    "\(shooter.name) 对 \(target.name) 发动猎手技能并击杀了恶魔。"
                )
            }
            markPlayer(shooter.id) { p in
                p.roleLog.append("Used the Slayer shot on \(target.name) successfully.")
            }
        } else {
            let engNote = targetWasAlive
                ? "\(target.name) was not the Demon."
                : "\(target.name) was already dead."
            let chnNote = targetWasAlive
                ? "\(target.name) 不是恶魔。"
                : "\(target.name) 已经死亡。"
            addLog(
                "\(shooter.name) used the Slayer shot on \(target.name), but it failed. \(engNote)",
                "\(shooter.name) 对 \(target.name) 发动猎手技能，但失败了。\(chnNote)"
            )
            markPlayer(shooter.id) { p in
                p.roleLog.append("Used the Slayer shot on \(target.name) unsuccessfully.")
            }
        }

        slayerSelectedTarget = nil
    }

    func executeNomineeIfSet() {
        guard !isVirginExecuting else {
            return
        }
        if isRiotDay {
            return
        }
        guard let targetId = leadingExecutionCandidate?.id else {
            if isExecutionTied {
                addLog("The highest vote total was tied. No execution occurred.", "最高票平票，本日无人被处决。")
            } else {
                addLog("No nomination reached the execution threshold of \(executionThreshold) vote(s).", "没有提名达到 \(executionThreshold) 票的处决门槛。")
            }
            endDayToNextNight()
            return
        }
        markPlayer(targetId) { $0.wasNominated = true }
        if goblinClaimedPlayerId == targetId, players.first(where: { $0.id == targetId })?.roleId == "goblin" {
            killIfAlive(targetId, reason: ui("Executed", "处决"))
            addLog("Goblin was executed after claiming Goblin. Evil wins.", "地精在公开宣称自己是地精后被处决。邪恶阵营获胜。")
            setGameOver(reason: .evilPopulationLead, side: .evil)
            return
        }
        if devilsAdvocateProtectedPlayerId == targetId,
           players.contains(where: { $0.alive && $0.roleId == "devils-advocate" && !isAbilitySuppressed($0) }) {
            hasExecutionToday = true
            executedPlayerToday = nil
            if mastermindExtraDayActive, let executed = players.first(where: { $0.id == targetId }) {
                if isPlayerGood(executed) {
                    addLog("A good player was executed on the Mastermind day. Evil wins.", "主谋额外日里有善良玩家被处决。邪恶阵营获胜。")
                    setGameOver(reason: .evilPopulationLead, side: .evil)
                } else {
                    addLog("An evil player was executed on the Mastermind day. Good wins.", "主谋额外日里有邪恶玩家被处决。善良阵营获胜。")
                    setGameOver(reason: .noDemonsAlive, side: .good)
                }
                return
            }
            addLog("\(playerName(targetId) ?? "Unknown") survived execution due to the Devil's Advocate.", "\(playerName(targetId) ?? "未知玩家") 因恶魔代言人而免于处决死亡。")
            endDayToNextNight()
            return
        }
        killIfAlive(targetId, reason: ui("Executed", "处决"))
        guard let postExecutionTarget = players.first(where: { $0.id == targetId }) else {
            endDayToNextNight()
            return
        }
        if postExecutionTarget.alive {
            hasExecutionToday = true
            executedPlayerToday = nil
            addLog(
                "\(postExecutionTarget.name) was executed but did not die.",
                "\(postExecutionTarget.name) 被处决但没有死亡。"
            )
            endDayToNextNight()
            return
        }
        if let executed = players.first(where: { $0.id == targetId }), isPlayerGood(executed), hasLeviathanInPlay {
            leviathanGoodExecutions += 1
            if leviathanGoodExecutions > 1 {
                addLog("More than 1 good player was executed while Leviathan is in play. Evil wins.", "利维坦在场时已有超过 1 名善良玩家被处决。邪恶阵营获胜。")
                setGameOver(reason: .evilPopulationLead, side: .evil)
                return
            }
        }
        if let executed = players.first(where: { $0.id == targetId }),
           roleTemplate(for: executed.roleId ?? "")?.team == .outsider {
            outsiderExecutedToday = true
        }
        if currentDayNumber == 1,
           let nominatorId = nominationNominatorByNominee[targetId],
           let nominator = playerLookup(by: nominatorId),
           nominator.roleId == "princess" {
            princessProtectedNightAfterDay = currentDayNumber
            addLog(
                ui("Princess nominated the executed player on the first day. The Demon does not kill tonight.", "公主在第一天提名了最终被处决的玩家。今夜恶魔不会杀人。")
            )
        }
        if let nominatorId = nominationNominatorByNominee[targetId],
           let nominator = playerLookup(by: nominatorId),
           nominator.roleId == "fearmonger",
           fearmongerTargetByPlayerId[nominatorId] == targetId {
            let evilWins = isPlayerGood(postExecutionTarget)
            addLog(
                ui(
                    "Fearmonger had their chosen player executed. \(evilWins ? "Evil" : "Good") wins.",
                    "恐惧贩子让自己选中的玩家被处决。\(evilWins ? "邪恶" : "善良")阵营获胜。"
                )
            )
            setGameOver(reason: evilWins ? .evilPopulationLead : .noDemonsAlive, side: evilWins ? .evil : .good)
            return
        }
        if mastermindExtraDayActive, let executed = players.first(where: { $0.id == targetId }) {
            if isPlayerGood(executed) {
                addLog("A good player was executed on the Mastermind day. Evil wins.", "主谋额外日里有善良玩家被处决。邪恶阵营获胜。")
                setGameOver(reason: .evilPopulationLead, side: .evil)
            } else {
                addLog("An evil player was executed on the Mastermind day. Good wins.", "主谋额外日里有邪恶玩家被处决。善良阵营获胜。")
                setGameOver(reason: .noDemonsAlive, side: .good)
            }
            return
        }
        if isGameOver { return }
        hasExecutionToday = true
        executedPlayerToday = targetId
        addLog("Execution: \(playerName(targetId) ?? "Unknown") with \(lockedVoteCount(for: targetId)) vote(s).", "处决：\(playerName(targetId) ?? "未知玩家")，票数 \(lockedVoteCount(for: targetId))。")
        endDayToNextNight()
    }

    func endDayToNextNight() {
        stopTimer()
        if hasLeviathanInPlay && currentDayNumber >= 5 {
            addLog("Day 5 ended with Leviathan still alive. Evil wins.", "第 5 天结束时利维坦仍然存活。邪恶阵营获胜。")
            setGameOver(reason: .evilPopulationLead, side: .evil)
            return
        }
        expireDuskLimitedEffects()
        phase = .night
        startNextNight()
    }

    func endDayWithoutExecution() {
        stopTimer()
        if mastermindExtraDayActive {
            addLog("No player was executed on the Mastermind day. Good wins.", "主谋额外日里无人被处决。善良阵营获胜。")
            setGameOver(reason: .noDemonsAlive, side: .good)
            return
        }
        if players.contains(where: { $0.alive && $0.roleId == "vortox" }) {
            addLog("No execution happened while Vortox is alive. Evil wins.", "沃托克斯存活时当天无人被处决。邪恶阵营获胜。")
            setGameOver(reason: .evilPopulationLead, side: .evil)
            return
        }
        if hasLeviathanInPlay && currentDayNumber >= 5 {
            addLog("Day 5 ended with Leviathan still alive. Evil wins.", "第 5 天结束时利维坦仍然存活。邪恶阵营获胜。")
            setGameOver(reason: .evilPopulationLead, side: .evil)
            return
        }
        if shouldMayorWinWithoutExecution() {
            setGameOver(reason: .mayorSurvived, side: .good)
            return
        }
        phase = .night
        startNextNight()
    }

    // MARK: - Timer

    func toggleTimer() {
        if timerRunning {
            stopTimer()
        } else {
            startTimer(seconds: phaseSecondsLeft)
        }
    }

    func addDayTime(seconds: Int) {
        guard phase == .day else { return }
        phaseSecondsLeft = max(0, phaseSecondsLeft + seconds)
    }

    func startTimer(seconds: Int) {
        stopTimer()
        phaseSecondsLeft = max(0, seconds)
        timerRunning = true
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self else { return }
            if self.phaseSecondsLeft > 0 {
                self.phaseSecondsLeft -= 1
            } else {
                self.stopTimer()
                if self.phase == .day {
                    self.endDayWithoutExecution()
                }
            }
        }
    }

    func stopTimer() {
        timer?.invalidate()
        timer = nil
        timerRunning = false
    }

    // MARK: - Fortune Teller Red Herring

    func fortuneTellerRedHerringCandidates() -> [PlayerCard] {
        players.filter { $0.alive && isPlayerGood($0) && $0.roleId != "fortuneteller" }
    }

    func selectFortuneTellerRedHerring(_ playerId: UUID) {
        fortuneTellerRedHerringId = playerId
        isSelectingFortuneTellerRedHerring = false
        addLog(
            "Fortune Teller red herring selected: \(playerName(playerId) ?? "unknown")",
            "占卜师的\"恶魔标记\"已选定：\(playerName(playerId) ?? "未知")"
        )
        buildNightQueue()
    }

    func isFortuneTellerRedHerring(_ playerId: UUID) -> Bool {
        fortuneTellerRedHerringId == playerId
    }

    func teamColor(for player: PlayerCard) -> Color {
        guard let roleId = player.roleId, let role = roleTemplate(for: roleId) else { return .gray }
        switch role.team {
        case .townsfolk: return .blue
        case .outsider: return Color(uiColor: .systemOrange)
        case .minion: return .red
        case .demon: return Color.red.opacity(0.7)
        case .traveller: return .gray
        }
    }

    // MARK: - Day abilities and vote validation

    func isVoteAllowed(voterId: UUID, nominee: UUID?) -> Bool {
        guard let voter = players.first(where: { $0.id == voterId }) else { return false }
        guard canParticipateInCurrentVote(voterId: voterId) else { return false }
        if !voter.alive {
            return bansheeEmpoweredPlayerIds.contains(voter.id) || voter.ghostVoteAvailable || votesByVoter[voterId] != nil
        }
        return isButlerVoteAllowed(voter: voter, nominee: nominee)
    }

    func butlerVoteReminder(voterId: UUID, nominee: UUID?) -> String? {
        guard let voter = players.first(where: { $0.id == voterId }),
              voter.alive,
              voter.roleId == "butler",
              let butlerMasterId = voter.butlerMasterId,
              let master = players.first(where: { $0.id == butlerMasterId }),
              master.alive else {
            return nil
        }
        guard let nominee else {
            return ui("Butler: wait for \(master.name) to vote first.", "管家：请等待主人 \(master.name) 先投票。")
        }
        if votesByVoter[master.id] == nominee {
            return ui("Butler: \(master.name) voted. You may vote now.", "管家：主人 \(master.name) 已投票，你现在可以投票。")
        }
        return ui("Butler: wait for \(master.name) to vote first.", "管家：请等待主人 \(master.name) 先投票。")
    }

    func canClaimGoblin(for nomineeId: UUID) -> Bool {
        phase == .day &&
        nomineeID == nomineeId &&
        players.contains(where: { $0.alive && $0.roleId == "goblin" })
    }

    func isButlerVoteAllowed(voter: PlayerCard, nominee: UUID?) -> Bool {
        guard let butlerMasterId = voter.butlerMasterId,
              voter.roleId == "butler",
              let master = players.first(where: { $0.id == butlerMasterId }),
              master.alive else {
            return true
        }
        guard let nominee else { return true }
        guard let masterChoice = votesByVoter[master.id] else { return false }
        return masterChoice == nominee
    }

    func reconcileButlerVotes(forMasterId masterId: UUID) {
        let masterChoice = votesByVoter[masterId]
        for player in players where player.roleId == "butler" && player.butlerMasterId == masterId {
            guard let butlerChoice = votesByVoter[player.id] else { continue }
            if masterChoice != butlerChoice {
                votesByVoter.removeValue(forKey: player.id)
            }
        }
    }

    func maybeProcessVirginNomination(_ nomineeId: UUID?, nominatorRegistersAsTownsfolk: Bool? = nil) {
        guard let nomineeId else { return }
        guard let nomineeIndex = players.firstIndex(where: { $0.id == nomineeId }) else { return }
        guard players[nomineeIndex].wasNominated == false else { return }
        guard players[nomineeIndex].roleId == "virgin" else { return }
        guard !isAbilitySuppressed(players[nomineeIndex]) else { return }
        guard let nominatorId = nominatorID,
              let nominator = playerLookup(by: nominatorId) else {
            return
        }
        let shouldRegisterAsTownsfolk = nominatorRegistersAsTownsfolk ?? (roleTemplate(for: nominator.roleId ?? "")?.team == .townsfolk)
        guard shouldRegisterAsTownsfolk else { return }
        markPlayer(nomineeId) { $0.wasNominated = true }
        isVirginExecuting = true
        addLog("Virgin was nominated for the first time. The Townsfolk nominator dies immediately.", "贞洁者首次被提名，镇民提名者立即死亡。")
        killIfAlive(nominatorId, reason: ui("Virgin first nomination", "贞洁者首次被提名"))
        isVirginExecuting = false
        hasExecutionToday = true
        executedPlayerToday = nominatorId
        if isGameOver {
            return
        }
        endDayToNextNight()
    }

    func needsVirginRegistrationChoice(for nomineeId: UUID?, nominatorId: UUID?) -> Bool {
        guard let nomineeId,
              let nominatorId,
              let nominee = playerLookup(by: nomineeId),
              let nominator = playerLookup(by: nominatorId) else {
            return false
        }
        guard nominee.roleId == "virgin",
              nominee.wasNominated == false,
              !isAbilitySuppressed(nominee),
              isFlexibleRegistrationPlayer(nominator) else {
            return false
        }
        return true
    }

    func shouldMayorWinWithoutExecution() -> Bool {
        let alivePlayers = players.filter(\.alive)
        guard alivePlayers.count == 3 else { return false }
        guard players.contains(where: { $0.roleId == "mayor" && $0.alive && !isAbilitySuppressed($0) }) else { return false }
        return !hasExecutionToday
    }

    func currentSlayer() -> PlayerCard? {
        actingDayPlayer(for: "slayer", requireUnsuppressed: false)
    }

    func canUseSlayerShot() -> Bool {
        guard let slayer = currentSlayer() else { return false }
        return !slayer.slayerShotUsed
    }

    var currentArtist: PlayerCard? {
        actingDayPlayer(for: "artist")
    }

    var currentFisherman: PlayerCard? {
        actingDayPlayer(for: "fisherman")
    }

    var currentAmnesiac: PlayerCard? {
        actingDayPlayer(for: "amnesiac", requireUnsuppressed: false)
    }

    var currentAlsaahir: PlayerCard? {
        actingDayPlayer(for: "alsaahir")
    }

    var currentCultLeader: PlayerCard? {
        actingDayPlayer(for: "cultleader")
    }

    var currentPsychopath: PlayerCard? {
        players.first(where: { $0.roleId == "psychopath" && $0.alive && !isAbilitySuppressed($0) })
    }

    var currentWizard: PlayerCard? {
        actingDayPlayer(for: "wizard")
    }

    var currentSavant: PlayerCard? {
        actingDayPlayer(for: "savant")
    }

    var currentGossip: PlayerCard? {
        actingDayPlayer(for: "gossip")
    }

    var currentJuggler: PlayerCard? {
        actingDayPlayer(for: "juggler")
    }

    var pendingMoonchild: PlayerCard? {
        guard let moonchildPendingPlayerId else { return nil }
        return playerLookup(by: moonchildPendingPlayerId)
    }

    var moonchildTargetCandidates: [PlayerCard] {
        players.filter { $0.alive && $0.id != moonchildPendingPlayerId }
    }

    func canUseArtistToday() -> Bool {
        guard phase == .day, let artist = currentArtist else { return false }
        return !artistUsedPlayerIds.contains(artist.id)
    }

    func canUseFishermanToday() -> Bool {
        guard phase == .day, let fisherman = currentFisherman else { return false }
        return !fishermanUsedPlayerIds.contains(fisherman.id)
    }

    func canUseAmnesiacToday() -> Bool {
        guard phase == .day, let amnesiac = currentAmnesiac else { return false }
        return !(amnesiacUsedByDay[amnesiac.id] ?? []).contains(currentDayNumber)
    }

    func canUseAlsaahirToday() -> Bool {
        phase == .day && currentAlsaahir != nil
    }

    func canUseCultLeaderToday() -> Bool {
        phase == .day && currentCultLeader != nil
    }

    func canUsePsychopathToday() -> Bool {
        guard phase == .day, let psychopath = currentPsychopath, currentNominator == nil, currentNominee == nil else { return false }
        return !(psychopathUsedByDay[psychopath.id] ?? []).contains(currentDayNumber)
    }

    func canUseWizardToday() -> Bool {
        guard phase == .day, let wizard = currentWizard else { return false }
        return !wizardUsedPlayerIds.contains(wizard.id)
    }

    func canUseSavantToday() -> Bool {
        guard phase == .day, let savant = currentSavant else { return false }
        return !(savantUsedByDay[savant.id] ?? []).contains(currentDayNumber)
    }

    func canUseGossipToday() -> Bool {
        guard phase == .day, let gossip = currentGossip else { return false }
        return !(gossipUsedByDay[gossip.id] ?? []).contains(currentDayNumber)
    }

    func canUseJugglerToday() -> Bool {
        guard phase == .day, currentDayNumber == 1, let juggler = currentJuggler else { return false }
        return jugglerGuessesByPlayerId[juggler.id] == nil
    }

    func recordArtistQuestion(_ note: String) {
        guard let artist = currentArtist, !artistUsedPlayerIds.contains(artist.id) else { return }
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        artistUsedPlayerIds.insert(artist.id)
        let isFakeArtist = isDisplayedDrunk(artist, actingAs: "artist")
        if isFakeArtist {
            markPlayer(artist.id) { player in
                player.roleLog.append(
                    trimmed.isEmpty
                    ? ui("Actually the Drunk. Used the fake Artist ability.", "真实身份是酒鬼。使用了假的艺术家能力。")
                    : ui("Actually the Drunk. Asked a fake Artist question: \(trimmed)", "真实身份是酒鬼。提出了一个假的艺术家问题：\(trimmed)")
                )
            }
            addLog(
                trimmed.isEmpty
                ? ui("Artist action for \(artist.name) was fake because they are actually the Drunk.", "\(artist.name) 的艺术家行动是假的，因为其真实身份是酒鬼。")
                : ui("\(artist.name) is actually the Drunk. Fake Artist question recorded: \(trimmed)", "\(artist.name) 的真实身份是酒鬼。已记录假的艺术家问题：\(trimmed)"),
                toneOverride: .drunk
            )
            return
        }
        if trimmed.isEmpty {
            markPlayer(artist.id) { player in
                player.roleLog.append(ui("Artist ability used (no question recorded).", "艺术家能力已使用（未记录问题）。"))
            }
            addLog(
                "Artist ability used for \(artist.name) (no question recorded).",
                "已为 \(artist.name) 使用艺术家能力（未记录问题）。"
            )
        } else {
            markPlayer(artist.id) { player in
                player.roleLog.append(ui("Asked an Artist question: \(trimmed)", "提出了艺术家问题：\(trimmed)"))
            }
            addLog(
                "Artist question recorded for \(artist.name): \(trimmed)",
                "已为 \(artist.name) 记录艺术家问题：\(trimmed)"
            )
        }
    }

    func recordFishermanAdvice(_ note: String) {
        guard let fisherman = currentFisherman, !fishermanUsedPlayerIds.contains(fisherman.id) else { return }
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        fishermanUsedPlayerIds.insert(fisherman.id)
        if isDisplayedDrunk(fisherman, actingAs: "fisherman") {
            markPlayer(fisherman.id) { player in
                player.roleLog.append(ui("Actually the Drunk. Fake Fisherman advice: \(trimmed)", "真实身份是酒鬼。假的渔夫建议：\(trimmed)"))
            }
            addLog(
                ui("\(fisherman.name) is actually the Drunk. Fake Fisherman advice recorded: \(trimmed)", "\(fisherman.name) 的真实身份是酒鬼。已记录假的渔夫建议：\(trimmed)"),
                toneOverride: .drunk
            )
            return
        }
        markPlayer(fisherman.id) { player in
            player.roleLog.append(ui("Fisherman advice: \(trimmed)", "渔夫建议：\(trimmed)"))
        }
        addLog(
            "Fisherman advice recorded for \(fisherman.name): \(trimmed)",
            "已为 \(fisherman.name) 记录渔夫建议：\(trimmed)"
        )
    }

    func recordAmnesiacMoment(_ note: String) {
        guard let amnesiac = currentAmnesiac else { return }
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        amnesiacUsedByDay[amnesiac.id, default: []].insert(currentDayNumber)
        if isDisplayedDrunk(amnesiac, actingAs: "amnesiac") {
            markPlayer(amnesiac.id) { player in
                player.roleLog.append(ui("Actually the Drunk. Fake Amnesiac ruling on day \(currentDayNumber): \(trimmed)", "真实身份是酒鬼。第 \(currentDayNumber) 天假的失忆者裁定：\(trimmed)"))
            }
            addLog(
                ui("\(amnesiac.name) is actually the Drunk. Fake Amnesiac note recorded: \(trimmed)", "\(amnesiac.name) 的真实身份是酒鬼。已记录假的失忆者裁定：\(trimmed)"),
                toneOverride: .drunk
            )
            return
        }
        markPlayer(amnesiac.id) { player in
            player.roleLog.append(ui("Amnesiac ruling on day \(currentDayNumber): \(trimmed)", "第 \(currentDayNumber) 天失忆者裁定：\(trimmed)"))
        }
        addLog(
            "Amnesiac note recorded for \(amnesiac.name): \(trimmed)",
            "已为 \(amnesiac.name) 记录失忆者裁定：\(trimmed)"
        )
    }

    func resolveAlsaahirGuess(_ note: String) {
        guard let alsaahir = currentAlsaahir else { return }
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        markPlayer(alsaahir.id) { player in
            player.roleLog.append(ui("Alsaahir guess: \(trimmed)", "阿尔萨希尔猜测：\(trimmed)"))
        }
        if isDisplayedDrunk(alsaahir, actingAs: "alsaahir") {
            addLog(
                ui("\(alsaahir.name) is actually the Drunk. Fake Alsaahir guess recorded: \(trimmed)", "\(alsaahir.name) 的真实身份是酒鬼。已记录假的阿尔萨希尔猜测：\(trimmed)"),
                toneOverride: .drunk
            )
            return
        }
        let normalized = trimmed.lowercased()
        let evilPlayers = players.filter { isPlayerEvil($0) }
        let allMatched = evilPlayers.allSatisfy { normalized.contains($0.name.lowercased()) }
        let guessedCount = players.filter { normalized.contains($0.name.lowercased()) }.count
        addLog(
            "Alsaahir guess recorded for \(alsaahir.name): \(trimmed)",
            "已为 \(alsaahir.name) 记录阿尔萨希尔猜测：\(trimmed)"
        )
        if allMatched && guessedCount == evilPlayers.count {
            setGameOver(reason: .noDemonsAlive, side: .good)
        }
    }

    func resolveCultLeaderVote(allGoodJoined: Bool) {
        guard let cultLeader = currentCultLeader else { return }
        if isDisplayedDrunk(cultLeader, actingAs: "cultleader") {
            addLog(
                ui("\(cultLeader.name) is actually the Drunk. Fake Cult Leader vote recorded.", "\(cultLeader.name) 的真实身份是酒鬼。已记录假的邪教领袖投票。"),
                toneOverride: .drunk
            )
            return
        }
        if allGoodJoined {
            let evil = isPlayerEvil(cultLeader)
            addLog(
                ui("All good players joined the cult. \(evil ? "Evil" : "Good") wins.", "所有善良玩家都加入了邪教。\(evil ? "邪恶" : "善良")阵营获胜。")
            )
            setGameOver(reason: evil ? .evilPopulationLead : .noDemonsAlive, side: evil ? .evil : .good)
        } else {
            addLog(
                ui("Cult Leader vote failed.", "邪教领袖集会失败。")
            )
        }
    }

    func psychopathTargetsToday() -> [PlayerCard] {
        players.filter { $0.alive }
    }

    func usePsychopathKill(targetId: UUID?) {
        guard let psychopath = currentPsychopath,
              !(psychopathUsedByDay[psychopath.id] ?? []).contains(currentDayNumber),
              let targetId,
              let target = playerLookup(by: targetId),
              target.alive else { return }
        psychopathUsedByDay[psychopath.id, default: []].insert(currentDayNumber)
        killIfAlive(target.id, reason: ui("Psychopath attack", "精神病人击杀"))
        addLog(
            ui("Psychopath \(psychopath.name) chose \(target.name) and they died if able.", "精神病人 \(psychopath.name) 选择了 \(target.name)，若可死亡则其死亡。")
        )
    }

    func recordWizardWish(_ note: String) {
        guard let wizard = currentWizard, !wizardUsedPlayerIds.contains(wizard.id) else { return }
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        wizardUsedPlayerIds.insert(wizard.id)
        if isDisplayedDrunk(wizard, actingAs: "wizard") {
            markPlayer(wizard.id) { player in
                player.roleLog.append(ui("Actually the Drunk. Fake Wizard wish: \(trimmed)", "真实身份是酒鬼。假的巫师愿望：\(trimmed)"))
            }
            addLog(
                ui("\(wizard.name) is actually the Drunk. Fake Wizard wish recorded: \(trimmed)", "\(wizard.name) 的真实身份是酒鬼。已记录假的巫师愿望：\(trimmed)"),
                toneOverride: .drunk
            )
            return
        }
        markPlayer(wizard.id) { player in
            player.roleLog.append(ui("Wizard wish: \(trimmed)", "巫师愿望：\(trimmed)"))
        }
        addLog(
            "Wizard wish recorded for \(wizard.name): \(trimmed)",
            "已为 \(wizard.name) 记录巫师愿望：\(trimmed)"
        )
    }

    func recordSavantInfo(_ note: String) {
        guard let savant = currentSavant else { return }
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        savantUsedByDay[savant.id, default: []].insert(currentDayNumber)
        if isDisplayedDrunk(savant, actingAs: "savant") {
            markPlayer(savant.id) { player in
                player.roleLog.append(
                    trimmed.isEmpty
                    ? ui("Actually the Drunk. Used fake Savant info on day \(currentDayNumber).", "真实身份是酒鬼。在第 \(currentDayNumber) 天使用了假的博学者信息。")
                    : ui("Actually the Drunk. Fake Savant info for day \(currentDayNumber): \(trimmed)", "真实身份是酒鬼。第 \(currentDayNumber) 天假的博学者信息：\(trimmed)")
                )
            }
            addLog(
                trimmed.isEmpty
                ? ui("\(savant.name) is actually the Drunk. Fake Savant use recorded for day \(currentDayNumber).", "\(savant.name) 的真实身份是酒鬼。已记录第 \(currentDayNumber) 天假的博学者使用。")
                : ui("\(savant.name) is actually the Drunk. Fake Savant info recorded: \(trimmed)", "\(savant.name) 的真实身份是酒鬼。已记录假的博学者信息：\(trimmed)"),
                toneOverride: .drunk
            )
            return
        }
        if trimmed.isEmpty {
            markPlayer(savant.id) { player in
                player.roleLog.append(ui("Savant ability used on day \(currentDayNumber) (no info recorded).", "第 \(currentDayNumber) 天博学者能力已使用（未记录信息）。"))
            }
            addLog(
                "Savant ability used for \(savant.name) on day \(currentDayNumber) (no info recorded).",
                "已为 \(savant.name) 在第 \(currentDayNumber) 天使用博学者能力（未记录信息）。"
            )
        } else {
            markPlayer(savant.id) { player in
                player.roleLog.append(ui("Savant info for day \(currentDayNumber): \(trimmed)", "第 \(currentDayNumber) 天博学者信息：\(trimmed)"))
            }
            addLog(
                "Savant info recorded for \(savant.name): \(trimmed)",
                "已为 \(savant.name) 记录博学者信息：\(trimmed)"
            )
        }
    }

    func recordGossipStatement(_ note: String, isTrue: Bool) {
        guard let gossip = currentGossip else { return }
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        gossipUsedByDay[gossip.id, default: []].insert(currentDayNumber)
        if isDisplayedDrunk(gossip, actingAs: "gossip") {
            let outcome = isTrue ? ui("true", "为真") : ui("false", "为假")
            markPlayer(gossip.id) { player in
                player.roleLog.append(ui("Actually the Drunk. Fake Gossip statement on day \(currentDayNumber): \(trimmed) (\(outcome)).", "真实身份是酒鬼。第 \(currentDayNumber) 天假的流言：\(trimmed)（\(outcome)）。"))
            }
            addLog(
                ui("\(gossip.name) is actually the Drunk. Fake Gossip statement recorded: \(trimmed) (\(isTrue ? "true" : "false")).", "\(gossip.name) 的真实身份是酒鬼。已记录假的流言：\(trimmed)（\(isTrue ? "为真" : "为假")）。"),
                toneOverride: .drunk
            )
            return
        }
        if isTrue {
            gossipKillTonight = true
        }
        let outcome = isTrue ? ui("true", "为真") : ui("false", "为假")
        markPlayer(gossip.id) { player in
            player.roleLog.append(ui("Gossip statement on day \(currentDayNumber): \(trimmed) (\(outcome)).", "第 \(currentDayNumber) 天流言：\(trimmed)（\(outcome)）。"))
        }
        addLog(
            "Gossip statement recorded for \(gossip.name): \(trimmed) (\(isTrue ? "true" : "false")).",
            "已为 \(gossip.name) 记录流言：\(trimmed)（\(isTrue ? "为真" : "为假")）。"
        )
    }

    func recordJugglerGuesses(_ note: String) {
        guard let juggler = currentJuggler, currentDayNumber == 1 else { return }
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        jugglerGuessesByPlayerId[juggler.id] = trimmed
        if isDisplayedDrunk(juggler, actingAs: "juggler") {
            markPlayer(juggler.id) { player in
                player.roleLog.append(ui("Actually the Drunk. Fake Juggler guesses: \(trimmed)", "真实身份是酒鬼。假的杂耍演员猜测：\(trimmed)"))
            }
            addLog(
                ui("\(juggler.name) is actually the Drunk. Fake Juggler guesses recorded: \(trimmed)", "\(juggler.name) 的真实身份是酒鬼。已记录假的杂耍演员猜测：\(trimmed)"),
                toneOverride: .drunk
            )
            return
        }
        markPlayer(juggler.id) { player in
            player.roleLog.append(ui("Juggler guesses: \(trimmed)", "杂耍演员猜测：\(trimmed)"))
        }
        addLog(
            "Juggler guesses recorded for \(juggler.name): \(trimmed)",
            "已为 \(juggler.name) 记录杂耍演员猜测：\(trimmed)"
        )
    }

    func chooseMoonchildTarget(_ playerId: UUID?) {
        guard let moonchild = pendingMoonchild else { return }
        guard let playerId, let target = playerLookup(by: playerId), target.alive else { return }
        moonchildPendingTargetId = playerId
        markPlayer(moonchild.id) { player in
            player.roleLog.append(ui("Chose \(target.name) as the Moonchild target.", "选择 \(target.name) 作为月之子目标。"))
        }
        addLog(
            "Moonchild \(moonchild.name) chose \(target.name).",
            "月之子 \(moonchild.name) 选择了 \(target.name)。"
        )
    }
}

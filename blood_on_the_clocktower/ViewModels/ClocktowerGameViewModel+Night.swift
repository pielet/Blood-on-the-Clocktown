import Foundation
import SwiftUI

extension ClocktowerGameViewModel {

    // MARK: - Night flow

    func continueFromAssignment() {
        guard isAssignmentReady else { return }
        if shouldShowImpBluffSetup {
            if impBluffRoleIds.count > impBluffSelectionTargetCount {
                impBluffRoleIds = Array(impBluffRoleIds.prefix(impBluffSelectionTargetCount))
            }
            impBluffShownPlayerId = impPlayerForSetup?.id
            phase = .impBluffs
            return
        }
        beginNight()
    }

    func toggleImpBluffRole(_ roleId: String) {
        if let index = impBluffRoleIds.firstIndex(of: roleId) {
            impBluffRoleIds.remove(at: index)
            return
        }
        guard impBluffRoleIds.count < impBluffSelectionTargetCount else { return }
        guard availableImpBluffRoles.contains(where: { $0.id == roleId }) else { return }
        impBluffRoleIds.append(roleId)
    }

    func confirmImpBluffSelection() {
        guard isImpBluffSelectionReady else { return }
        phase = .impBluffsReveal
    }

    func confirmImpBluffsAndBeginNight() {
        guard isImpBluffSelectionReady else { return }
        if let impPlayer = impPlayerForSetup {
            let bluffRoleIds = selectedImpBluffRoles.map(\.id).joined(separator: ",")
            markPlayer(impPlayer.id) { player in
                player.roleLog.append("\(roleActionRecordPrefix)imp-bluffs|\(player.name)||\(bluffRoleIds)")
            }
            let bluffNames = selectedImpBluffRoles.map { localizedRoleName($0) }.joined(separator: ", ")
            addLog(
                "Imp bluffs shown to \(impPlayer.name): \(bluffNames).",
                "已向 \(impPlayer.name) 展示小恶魔可伪装角色：\(bluffNames)。"
            )
        }
        beginNight()
    }

    func beginNight() {
        clearNightState()
        guard isAssignmentReady else { return }
        stopTimer()
        isGrimoireShowingBacks = true
        clearGrimoireReveals()
        isFirstNightPhase = true
        prepareFirstNightExperimentalState()
        phase = .firstNight

        if fortuneTellerRedHerringId == nil,
           player(for: "fortuneteller") != nil {
            isSelectingFortuneTellerRedHerring = true
            return
        }
        buildNightQueue()
    }

    func startNextNight() {
        if impDiedTonight {
            promoteMinionAfterImpDeath()
            if isGameOver {
                return
            }
        }
        clearNightState()
        stopTimer()
        isFirstNightPhase = false
        isGrimoireShowingBacks = true
        clearGrimoireReveals()
        phase = .night
        buildNightQueue()
    }

    func buildNightQueue() {
        updateNoDashiiPoisoning()
        var queue: [NightStepTemplate] = []
        let order = isFirstNightPhase ? phaseTemplate.nightOrderFirst : phaseTemplate.nightOrderStandard
        queue.append(contentsOf: order.filter { step in
            // Keep steps that might activate later in the night (e.g., Ravenkeeper dies mid-night)
            // but only if the player is still alive — they could die during this night.
            // Dead players from previous nights should not appear.
            if case .ifActorDiedTonight = step.condition {
                guard let actor = player(for: step.roleId) else { return false }
                return actor.alive
            }
            return shouldKeepNightStep(step)
        })
        currentNightSteps = queue
        currentNightStepIndex = 0
        currentNightTargets.removeAll()
        currentNightNote = ""
        currentNightAlignmentSelections.removeAll()
        advanceToCurrentActiveNightStep()
    }

    func shouldKeepNightStep(_ item: NightStepTemplate) -> Bool {
        if let actor = player(for: item.roleId) {
            // Roles that activate on death (e.g., Ravenkeeper) bypass the alive check
            let diedTonightCondition: Bool
            if case let .ifActorDiedTonight(roleId) = item.condition {
                diedTonightCondition = diedByDemonTonight(actor, actingAs: roleId)
            } else {
                diedTonightCondition = false
            }
            guard canWakeAtNight(actor) || diedTonightCondition,
                  let role = roleTemplate(for: item.roleId),
                  isFirstNightPhase ? role.firstNight : role.otherNights else {
                return false
            }
            if exorcisedPlayerId == actor.id, role.team == .demon {
                return false
            }
            if item.roleId == "nightwatchman", nightwatchmanUsedPlayerIds.contains(actor.id) {
                return false
            }
            if item.roleId == "huntsman", huntsmanUsedPlayerIds.contains(actor.id) {
                return false
            }
            if item.roleId == "assassin", assassinUsedPlayerIds.contains(actor.id) {
                return false
            }
            if item.roleId == "professor", professorUsedPlayerIds.contains(actor.id) {
                return false
            }
            if item.roleId == "courtier", courtierUsedPlayerIds.contains(actor.id) {
                return false
            }
            if item.roleId == "engineer", engineerUsedPlayerIds.contains(actor.id) {
                return false
            }
            if item.roleId == "seamstress", seamstressUsedPlayerIds.contains(actor.id) {
                return false
            }
            if item.roleId == "juggler" {
                return jugglerGuessesByPlayerId[actor.id] != nil && !jugglerResolvedPlayerIds.contains(actor.id)
            }
            if item.roleId == "king" {
                return players.filter(\.alive).count <= players.filter { !$0.alive }.count
            }
            if item.roleId == "choirboy" {
                return kingKilledByDemonPlayerId != nil
            }
            if item.roleId == "fearmonger" || item.roleId == "harpy" || item.roleId == "acrobat" {
                return true
            }
            if item.roleId == "scarletwoman" {
                return false
            }
            if item.roleId == "summoner" {
                return currentDayNumber >= 2
            }
            // Suppressed players still wake so the Storyteller can provide false info
            // or accept targets for an ability that ultimately has no effect.
            if item.roleId == "bountyhunter" {
                if isFirstNightPhase {
                    return true
                }
                return shouldWakeBountyHunterTonight()
            }
            switch item.condition {
            case .always:
                return true
            case .ifExecutionHappenedToday:
                return executedPlayerToday != nil
            case let .ifRoleInPlay(roleId):
                return playerActsAsRole(actor, roleId: roleId)
            case let .ifActorDiedTonight(roleId):
                return diedByDemonTonight(actor, actingAs: roleId)
            }
        }
        return false
    }

    func diedByDemonTonight(_ player: PlayerCard, actingAs roleId: String) -> Bool {
        guard playerActsAsRole(player, roleId: roleId) else { return false }
        return demonKilledTonight.contains(player.id)
    }

    func player(for roleId: String) -> PlayerCard? {
        actingPlayer(for: roleId, requireCanWake: true) ??
        actingPlayer(for: roleId)
    }

    func wakeProgressPlayer(for step: NightStepTemplate) -> PlayerCard? {
        player(for: step.roleId)
    }

    func advanceToCurrentActiveNightStep() {
        while currentNightStepIndex < currentNightSteps.count {
            guard let step = currentNightStep else { return }
            if shouldKeepNightStep(step) {
                return
            }
            skippedNightStepIndices.insert(currentNightStepIndex)
            currentNightStepIndex += 1
        }
        if currentNightStepIndex >= currentNightSteps.count {
            resolveNightDawn()
        }
    }

    var currentNightStep: NightStepTemplate? {
        guard currentNightSteps.indices.contains(currentNightStepIndex) else { return nil }
        return currentNightSteps[currentNightStepIndex]
    }

    var currentNightActor: PlayerCard? {
        guard let step = currentNightStep else { return nil }
        return player(for: step.roleId)
    }

    var currentNightReminderHighlightStyle: NightReminderHighlightStyle? {
        guard let step = currentNightStep else { return nil }
        return currentNightReminderHighlightStyle(for: step.roleId)
    }

    func currentNightTargetLimit() -> Int {
        guard let step = currentNightStep, let role = roleTemplate(for: step.roleId) else { return 0 }
        if step.roleId == "po-demon" {
            guard let actor = currentNightActor else { return 1 }
            return poChargedPlayerIds.contains(actor.id) ? 3 : 1
        }
        return isFirstNightPhase ? role.targetCountFirstNight : role.targetCountNight
    }

    enum NightTargetSelectionMode {
        case none
        case alivePlayers(excludingActor: Bool, goodOnly: Bool)
        case allPlayers(excludingActor: Bool)
        case deadPlayers
        case manualOnly
    }

    func nightTargetSelectionMode(for roleId: String) -> NightTargetSelectionMode {
        switch roleId {
        case "acrobat":
            return .allPlayers(excludingActor: false)
        case "grandmother":
            return .alivePlayers(excludingActor: true, goodOnly: true)
        case "sailor":
            return .alivePlayers(excludingActor: false, goodOnly: false)
        case "chambermaid":
            return .alivePlayers(excludingActor: true, goodOnly: false)
        case "harpy", "alhadikhia":
            return .allPlayers(excludingActor: false)
        case "courtier":
            return .manualOnly
        case "exorcist", "innkeeper", "godfather", "devils-advocate", "zombuul", "pukka", "shabaloth", "po-demon", "washerwoman", "librarian", "investigator", "poisoner", "widow", "seamstress", "fortuneteller", "lordoftyphon":
            return .alivePlayers(excludingActor: false, goodOnly: false)
        case "monk", "nightwatchman", "butler", "lleech", "lycanthrope", "preacher", "villageidiot", "snake-charmer", "fang-gu", "vigormortis", "no-dashii", "huntsman", "summoner", "noble", "dreamer", "vortox":
            return .alivePlayers(excludingActor: true, goodOnly: false)
        case "imp":
            return .alivePlayers(excludingActor: false, goodOnly: false)
        case "fearmonger":
            return .allPlayers(excludingActor: false)
        case "professor":
            return .deadPlayers
        case "gambler", "assassin":
            return .allPlayers(excludingActor: false)
        case "ravenkeeper":
            return .allPlayers(excludingActor: false)
        case "lunatic":
            return .alivePlayers(excludingActor: true, goodOnly: false)
        default:
            return currentNightTargetLimit() > 0 ? .manualOnly : .none
        }
    }

    func canUseNightTargetPicker(for roleId: String) -> Bool {
        switch nightTargetSelectionMode(for: roleId) {
        case .alivePlayers, .allPlayers, .deadPlayers:
            return true
        case .none, .manualOnly:
            return false
        }
    }

    func currentNightTargetPrompt() -> String {
        guard let step = currentNightStep else { return ui("Targets", "可选目标") }
        switch step.roleId {
        case "acrobat":
            return ui("Choose 1 player to track for drunk or poison.", "选择 1 名玩家，观察其是否醉酒或中毒")
        case "grandmother":
            return ui("Choose 1 good player to learn.", "选择 1 名善良玩家作为祖母目标")
        case "sailor":
            return ui("Choose 1 living player. One of you becomes drunk until dusk.", "选择 1 名存活玩家。你们其中一人将醉酒至黄昏")
        case "chambermaid":
            return ui("Choose 2 living players to count who woke tonight.", "选择 2 名存活玩家，统计其中几人今晚醒来")
        case "innkeeper":
            return ui("Choose 2 living players to protect. One becomes drunk until dusk.", "选择 2 名存活玩家进行保护。其中 1 人会醉酒至黄昏")
        case "fearmonger":
            return ui("Choose 1 player to be your Fearmonger target.", "选择 1 名玩家作为恐惧贩子的目标")
        case "imp":
            return ui(
                "Choose 1 living player to kill. You may choose yourself; if you do, the Storyteller will choose which living Minion becomes the new Imp.",
                "选择 1 名存活玩家进行击杀。你也可以选择自己；若如此，说书人随后可从存活爪牙中选择谁成为新的小恶魔。"
            )
        case "gambler":
            return ui("Choose 1 player, then enter the guessed character below.", "选择 1 名玩家，然后在下方填写猜测的角色")
        case "courtier":
            return ui("Enter a character name below.", "请在下方输入一个角色名称")
        case "lunatic":
            return ui("Choose the fake Demon target.", "选择疯子以为自己夜杀的目标")
        case "harpy":
            return ui("Choose 2 players. The first must be mad that the second is evil tomorrow.", "选择 2 名玩家。第一名玩家明天必须坚称第二名玩家是邪恶")
        case "huntsman":
            return ui("Choose 1 living player to check for the Damsel.", "选择 1 名存活玩家，检查其是否为少女")
        case "lordoftyphon":
            return ui("Choose 1 player to die.", "选择 1 名玩家死亡")
        case "alhadikhia":
            return ui("Choose 3 players. Record live/die choices below.", "选择 3 名玩家，并在下方记录其生死选择")
        case "noble":
            return ui("Choose 3 players (exactly 1 must be evil) to reveal.", "选择 3 名玩家（恰好 1 名邪恶）展示给贵族")
        case "dreamer":
            return ui("Choose a player to learn about.", "选择 1 名玩家进行梦境探查")
        case "vortox":
            return ui("Choose a player to kill.", "选择 1 名玩家作为击杀目标")
        case "washerwoman":
            return ui("Choose 2 players, then choose the Townsfolk role shown below.", "选择 2 名玩家，然后在下方选择要告知洗衣妇的镇民角色")
        case "librarian":
            return ui("Choose 2 players, then choose the Outsider role shown below. If none are in play, choose 'No Outsider'.", "选择 2 名玩家，然后在下方选择要告知图书管理员的外来者角色。若场上没有外来者，请选择“没有外来者”")
        case "investigator":
            return ui("Choose 2 players, then choose the Minion role shown below.", "选择 2 名玩家，然后在下方选择要告知调查员的爪牙角色")
        default:
            return ui("Targets", "可选目标")
        }
    }

    func currentNightNotePrompt() -> String {
        guard let step = currentNightStep else { return ui("Night result / notes (optional)", "输入夜间结果/备注（可选）") }
        if isCurrentNightDisplayedDrunk(for: step.roleId) {
            return ui("Record the false result shown to the Drunk", "记录展示给酒鬼的错误结果")
        }
        switch step.roleId {
        case "alchemist":
            return ui("Enter the granted Minion ability", "输入炼金术士获得的爪牙能力")
        case "amnesiac":
            return ui("Record the ability ruling or hint", "记录失忆者本次能力裁定或提示")
        case "boffin":
            return ui("Enter the good ability granted to the Demon", "输入博芬赋予恶魔的善良能力")
        case "cultleader":
            return ui("Optional cult alignment note", "可选：记录邪教领袖阵营变化")
        case "gambler":
            return ui("Enter the guessed character name", "输入赌徒猜测的角色名称")
        case "courtier":
            return ui("Enter the character to make drunk for 3 days and nights", "输入朝臣要致醉 3 天 3 夜的角色")
        case "engineer":
            return ui("Enter the Demon or Minion role(s) to create", "输入工程师要改成的恶魔或爪牙角色")
        case "fortuneteller", "empath", "chef", "washerwoman", "librarian", "investigator", "juggler":
            return ui("Record the storyteller result", "记录说书人给出的结果")
        case "highpriestess":
            return ui("Record the player the High Priestess is led to", "记录女祭司被引导到的玩家")
        case "legion":
            return ui("Optional victim or storyteller note", "可选：输入死者或说书人备注")
        case "lilmonsta":
            return ui("Record the babysitter and any victim", "记录照看者和可能的死者")
        case "king":
            return ui("Record the alive character shown to the King", "记录告知国王的存活角色")
        case "knight", "shugenja", "steward":
            return ui("Record the storyteller result", "记录说书人给出的结果")
        case "noble":
            return ui("Notes (optional)", "备注（可选）")
        case "pixie":
            return ui("Select or enter the Townsfolk role the Pixie learns", "选择或输入小精灵得知的镇民角色")
        case "dreamer":
            return ui("Enter the 2 characters shown (1 good, 1 evil)", "输入展示的 2 个角色（1 善良，1 邪恶）")
        case "mathematician":
            return ui("Enter the number of malfunctioning abilities", "输入异常能力的数量")
        case "lunatic":
            return ui("Optional fake-Demon note", "可选：记录疯子得到的假恶魔信息")
        case "mezepheles":
            return ui("Enter the secret word", "输入梅泽菲勒斯的秘密单词")
        case "ojo":
            return ui("Enter the chosen character, or role -> player for the death", "输入奥霍选择的角色，或使用“角色 -> 玩家”记录死亡")
        case "organgrinder":
            return ui("Record whether secret voting is in effect", "记录是否启用秘密投票")
        case "summoner":
            return ui("Enter the Demon to summon, or Demon -> player", "输入召唤师要召唤的恶魔，或使用“恶魔 -> 玩家”")
        case "wizard":
            return ui("Record the wish and outcome", "记录愿望及其代价/结果")
        case "xaan":
            return ui("Optional Xaan note", "可选：记录夏安之夜")
        case "yaggababble":
            return ui("Enter the phrase or the chosen victim", "输入亚嘎巴布尔的短语或受害者")
        default:
            return ui("Night result / notes (optional)", "输入夜间结果/备注（可选）")
        }
    }

    func isFlexibleRegistrationPlayer(_ player: PlayerCard) -> Bool {
        player.roleId == "spy" || player.roleId == "recluse"
    }

    func flexibleRegisteredTeams(for player: PlayerCard) -> Set<RoleTeam> {
        switch player.roleId {
        case "spy":
            return [.townsfolk, .outsider]
        case "recluse":
            return [.minion, .demon]
        default:
            return []
        }
    }

    func canRegister(_ player: PlayerCard, as team: RoleTeam) -> Bool {
        flexibleRegisteredTeams(for: player).contains(team)
    }

    func troubleBrewingInfoTeam(for roleId: String) -> RoleTeam? {
        switch roleId {
        case "washerwoman":
            return .townsfolk
        case "librarian":
            return .outsider
        case "investigator":
            return .minion
        default:
            return nil
        }
    }

    func flexibleRegistrationFallbackPlayer(for team: RoleTeam) -> PlayerCard? {
        players.first { player in
            isFlexibleRegistrationPlayer(player) && canRegister(player, as: team)
        }
    }

    func troubleBrewingRoleChoiceOption(for role: RoleTemplate, team: RoleTeam) -> NightRoleChoiceOption {
        let roleIsInPlay = players.contains { $0.roleId == role.id }
        let registeringPlayerId = roleIsInPlay ? nil : flexibleRegistrationFallbackPlayer(for: team)?.id
        return NightRoleChoiceOption(
            id: encodedNightRoleChoiceId(roleId: role.id, registeringPlayerId: registeringPlayerId),
            roleId: role.id
        )
    }

    func sortedRoleOptions(ids: Set<String>) -> [NightRoleChoiceOption] {
        ids
            .compactMap { roleId in roleTemplate(for: roleId) }
            .sorted {
                localizedRoleName($0).localizedStandardCompare(localizedRoleName($1)) == .orderedAscending
            }
            .map { NightRoleChoiceOption(id: $0.id, roleId: $0.id) }
    }

    func currentNightExactRevealPlayer(for roleId: String) -> PlayerCard? {
        switch roleId {
        case "undertaker":
            guard let executedPlayerToday else { return nil }
            return playerLookup(by: executedPlayerToday)
        case "grandmother", "ravenkeeper":
            guard let targetId = currentNightTargets.first else { return nil }
            return playerLookup(by: targetId)
        default:
            return nil
        }
    }

    func exactRevealRoleChoiceOptions(for player: PlayerCard) -> [NightRoleChoiceOption] {
        guard let actualRoleId = player.roleId else { return [] }
        var roleIds = Set([actualRoleId])
        for role in phaseTemplate.roles where canRegister(player, as: role.team) {
            roleIds.insert(role.id)
        }
        return sortedRoleOptions(ids: roleIds)
    }

    func resolvedExactRevealRole(for player: PlayerCard, selectedRoleId: String?) -> RoleTemplate? {
        guard let actualRoleId = player.roleId else { return nil }
        let options = Set(exactRevealRoleChoiceOptions(for: player).compactMap(\.roleId))
        if let selectedRoleId,
           options.contains(selectedRoleId),
           let selectedRole = roleTemplate(for: selectedRoleId) {
            return selectedRole
        }
        return roleTemplate(for: actualRoleId)
    }

    func shouldUseFullRolePoolForExactReveal(roleId: String) -> Bool {
        guard roleId == "ravenkeeper",
              let actor = currentNightActor else {
            return false
        }
        return isAbilitySuppressed(actor) || isDisplayedDrunk(actor, actingAs: roleId)
    }

    func shouldUseFullRolePoolForTroubleBrewingInfo(team: RoleTeam) -> Bool {
        if isCurrentNightDisplayedDrunk() {
            return true
        }
        if let actor = currentNightActor, isAbilitySuppressed(actor) {
            return true
        }
        // If any alive flexible registration player in the game can register as this team,
        // the storyteller may show any role of that team (Spy → townsfolk/outsider, Recluse → minion/demon)
        if players.contains(where: { $0.alive && isFlexibleRegistrationPlayer($0) && canRegister($0, as: team) }) {
            return true
        }
        return false
    }

    func disallowedFlexibleRegistrationRoleIds(for detectorRoleId: String) -> Set<String> {
        [
            detectorRoleId,
            "marionette"
        ]
    }

    func currentNightAlignmentChoicePlayers() -> [PlayerCard] {
        guard let step = currentNightStep else { return [] }
        switch step.roleId {
        case "villageidiot", "seamstress":
            return currentNightTargets
                .compactMap(playerLookup(by:))
                .filter(isFlexibleRegistrationPlayer)
        case "empath":
            guard let actor = currentNightActor else { return [] }
            return aliveNeighbors(of: actor)
                .filter(isFlexibleRegistrationPlayer)
        case "chef":
            return players.filter { $0.alive && isFlexibleRegistrationPlayer($0) }
        case "fortuneteller":
            return currentNightTargets
                .compactMap(playerLookup(by:))
                .filter(isFlexibleRegistrationPlayer)
        default:
            return []
        }
    }

    func currentNightAlignmentPrompt(for player: PlayerCard) -> String {
        let roleName = localizedRoleName(roleTemplate(for: player.roleId ?? ""))
        return ui(
            "Choose how \(player.name) (\(roleName)) registers for this alignment result.",
            "选择 \(player.name)（\(roleName)）在本次阵营判定中如何登记。"
        )
    }

    func currentNightAlignmentSelection(for playerId: UUID) -> Bool? {
        currentNightAlignmentSelections[playerId]
    }

    func setCurrentNightAlignmentSelection(_ isEvil: Bool?, for playerId: UUID) {
        if let isEvil {
            currentNightAlignmentSelections[playerId] = isEvil
        } else {
            currentNightAlignmentSelections.removeValue(forKey: playerId)
        }
    }

    func detectedIsEvil(_ player: PlayerCard) -> Bool {
        currentNightAlignmentSelections[player.id] ?? isPlayerEvil(player)
    }

    var isAwaitingVirginRegistrationChoice: Bool {
        pendingVirginRegistrationNominatorId != nil
    }

    var pendingVirginRegistrationPlayer: PlayerCard? {
        guard let pendingVirginRegistrationNominatorId else { return nil }
        return playerLookup(by: pendingVirginRegistrationNominatorId)
    }

    func resolvePendingVirginRegistration(registersAsTownsfolk: Bool) {
        let nominee = nomineeID
        pendingVirginRegistrationNominatorId = nil
        maybeProcessVirginNomination(nominee, nominatorRegistersAsTownsfolk: registersAsTownsfolk)
    }

    func hasNightRoleChoices(for roleId: String) -> Bool {
        switch roleId {
        case "washerwoman", "librarian", "investigator":
            return true
        case "undertaker", "grandmother", "ravenkeeper":
            return !nightRoleChoices(for: roleId).isEmpty
        default:
            return false
        }
    }

    func shouldShowNightNoteField(for roleId: String) -> Bool {
        if isCurrentNightDisplayedDrunk(for: roleId) && !hasNightRoleChoices(for: roleId) {
            return true
        }
        switch roleId {
        case "undertaker", "grandmother", "empath", "chef":
            return false
        default:
            return !hasNightRoleChoices(for: roleId)
        }
    }

    func currentNightRoleChoicePrompt() -> String {
        guard let step = currentNightStep else { return ui("Choose a role", "选择一个角色") }
        switch step.roleId {
        case "washerwoman":
            return ui("Choose the Townsfolk role shown to Washerwoman.", "选择要告知洗衣妇的镇民角色")
        case "librarian":
            return ui("Choose the Outsider role shown to Librarian.", "选择要告知图书管理员的外来者角色")
        case "investigator":
            return ui("Choose the Minion role shown to Investigator.", "选择要告知调查员的爪牙角色")
        case "undertaker":
            if let player = currentNightExactRevealPlayer(for: step.roleId) {
                return ui("Choose the role shown to Undertaker for \(player.name).", "选择要告知送葬者的 \(player.name) 角色。")
            }
            return ui("Choose the role shown to Undertaker.", "选择要告知送葬者的角色")
        case "grandmother":
            if let player = currentNightExactRevealPlayer(for: step.roleId) {
                return ui("Choose the role Grandmother learns for \(player.name).", "选择祖母获知的 \(player.name) 角色。")
            }
            return ui("Choose the role shown to Grandmother.", "选择要告知祖母的角色")
        case "ravenkeeper":
            if let player = currentNightExactRevealPlayer(for: step.roleId) {
                return ui("Choose the role shown for \(player.name).", "选择展示给守鸦人的 \(player.name) 角色。")
            }
            return ui("Choose the role shown to Ravenkeeper.", "选择要告知守鸦人的角色")
        default:
            return ui("Choose a role", "选择一个角色")
        }
    }

    func autoSelectPlayerForRoleChoice(_ option: NightRoleChoiceOption?) {
        guard let step = currentNightStep else { return }
        guard ["washerwoman", "librarian", "investigator"].contains(step.roleId) else { return }
        guard let option else {
            currentNightTargets.removeAll()
            return
        }
        guard let roleId = option.roleId else {
            currentNightTargets.removeAll()
            return
        }
        if let registeringPlayerId = decodedNightRoleChoice(from: option.id).registeringPlayerId {
            currentNightTargets = [registeringPlayerId]
            return
        }
        if let match = players.first(where: { $0.roleId == roleId }) {
            currentNightTargets = [match.id]
            return
        }
        if let matchingTeam = troubleBrewingInfoTeam(for: step.roleId),
           let fallbackPlayer = flexibleRegistrationFallbackPlayer(for: matchingTeam) {
            currentNightTargets = [fallbackPlayer.id]
        }
    }

    func currentNightRoleChoices() -> [NightRoleChoiceOption] {
        guard let step = currentNightStep else { return [] }
        return nightRoleChoices(for: step.roleId)
    }

    func nightInformationalText(for roleId: String) -> String? {
        if let guidance = currentNightDrunkGuidance(roleId: roleId) {
            return guidance
        }
        switch roleId {
        case "empath", "chef":
            return currentNightPassiveInfoSummaryText()
        case "undertaker":
            guard let result = undertakerExecutionResult(selectedRoleId: currentNightNote) else { return nil }
            return ui(
                "Show Undertaker: \(result.player.name) is the \(localizedRoleName(result.role)).",
                "告知送葬者：\(result.player.name) 显示为 \(localizedRoleName(result.role))。"
            )
        default:
            return nil
        }
    }

    func localizedNightRoleChoiceLabel(_ option: NightRoleChoiceOption) -> String {
        if let roleId = option.roleId {
            return localizedRoleName(roleTemplate(for: roleId))
        }
        return ui("No Outsider", "没有外来者")
    }

    func nightRoleChoices(for roleId: String) -> [NightRoleChoiceOption] {
        if shouldUseFullRolePoolForExactReveal(roleId: roleId) {
            let roleIds = Set(phaseTemplate.roles
                .filter { $0.team != .traveller }
                .map { $0.id })
            return sortedRoleOptions(ids: roleIds)
        }

        let matchingTeam = troubleBrewingInfoTeam(for: roleId)

        if let exactRevealPlayer = currentNightExactRevealPlayer(for: roleId),
           isFlexibleRegistrationPlayer(exactRevealPlayer) {
            return exactRevealRoleChoiceOptions(for: exactRevealPlayer)
        }

        guard let matchingTeam else { return [] }

        let shouldUseFullRolePool = shouldUseFullRolePoolForTroubleBrewingInfo(team: matchingTeam)

        if shouldUseFullRolePool {
            let excludedRoleIds = disallowedFlexibleRegistrationRoleIds(for: roleId)
            var options = phaseTemplate.roles
                .filter { role in
                    role.team == matchingTeam &&
                    role.team != .traveller &&
                    !excludedRoleIds.contains(role.id)
                }
                .sorted {
                    localizedRoleName($0).localizedStandardCompare(localizedRoleName($1)) == .orderedAscending
                }
                .map { troubleBrewingRoleChoiceOption(for: $0, team: matchingTeam) }

            if roleId == "librarian" {
                options.insert(NightRoleChoiceOption(id: noOutsiderChoiceID, roleId: nil), at: 0)
            }

            return options
        }

        let matchingRoles = Dictionary(
            grouping: players.compactMap { player -> RoleTemplate? in
                guard let roleId = player.roleId,
                      let role = roleTemplate(for: roleId),
                      role.team == matchingTeam else {
                    return nil
                }
                return role
            },
            by: \.id
        )
        .values
        .compactMap(\.first)
        .sorted {
            localizedRoleName($0).localizedStandardCompare(localizedRoleName($1)) == .orderedAscending
        }

        if roleId == "librarian", matchingRoles.isEmpty {
            return [NightRoleChoiceOption(id: noOutsiderChoiceID, roleId: nil)]
        }

        return matchingRoles.map { NightRoleChoiceOption(id: $0.id, roleId: $0.id) }
    }

    func undertakerExecutionResult(selectedRoleId: String? = nil) -> (player: PlayerCard, role: RoleTemplate)? {
        guard let executedPlayerToday,
              let executedPlayer = playerLookup(by: executedPlayerToday),
              let executedRole = resolvedExactRevealRole(for: executedPlayer, selectedRoleId: selectedRoleId) else {
            return nil
        }
        return (executedPlayer, executedRole)
    }

    func currentNightCandidates() -> [PlayerCard] {
        guard let step = currentNightStep else { return players.filter(\.alive) }
        guard let actor = currentNightActor else { return players.filter(\.alive) }
        switch nightTargetSelectionMode(for: step.roleId) {
        case let .alivePlayers(excludingActor, goodOnly):
            return players.filter { candidate in
                guard candidate.alive else { return false }
                if excludingActor && candidate.id == actor.id {
                    return false
                }
                if goodOnly && !isPlayerGood(candidate) {
                    if step.roleId == "grandmother" && isFlexibleRegistrationPlayer(candidate) {
                        return true
                    }
                    return false
                }
                return true
            }
        case let .allPlayers(excludingActor):
            return players.filter { candidate in
                !excludingActor || candidate.id != actor.id
            }
        case .deadPlayers:
            return players.filter { !$0.alive }
        case .none, .manualOnly:
            return []
        }
    }

    func doesPlayerWakeTonightDueToOwnAbility(_ player: PlayerCard) -> Bool {
        guard player.alive,
              let roleId = player.roleId else {
            return false
        }
        let order = isFirstNightPhase ? phaseTemplate.nightOrderFirst : phaseTemplate.nightOrderStandard
        return order.contains { step in
            step.roleId == roleId &&
            self.player(for: step.roleId)?.id == player.id &&
            self.shouldKeepNightStep(step)
        }
    }

    func countWakingPlayers(for targetIds: [UUID]) -> Int {
        targetIds.compactMap { playerLookup(by: $0) }
            .filter { doesPlayerWakeTonightDueToOwnAbility($0) }
            .count
    }

    func handleGrandmotherAction(actor: PlayerCard, targets: [UUID], shownRoleId: String) {
        guard let targetId = targets.first,
              let targetPlayer = playerLookup(by: targetId),
              let targetRole = resolvedExactRevealRole(for: targetPlayer, selectedRoleId: shownRoleId) else {
            appendActionLog("\(actor.name) woke as Grandmother but chose no player.", "\(actor.name) 作为祖母醒来，但没有选择玩家。")
            return
        }
        grandmotherLinkedPlayerIds[actor.id] = targetId
        let revealedRoleName = localizedRoleName(targetRole)
        appendActionLog("\(actor.name) learned that \(targetPlayer.name) is \(revealedRoleName).", "\(actor.name) 得知 \(targetPlayer.name) 是 \(revealedRoleName)。")
        markPlayer(actor.id) { player in
            player.roleLog.append(ui("Learned that \(targetPlayer.name) is \(revealedRoleName).", "得知 \(targetPlayer.name) 是 \(revealedRoleName)。"))
        }
    }

    func handleSailorAction(actor: PlayerCard, targets: [UUID]) {
        guard let targetId = targets.first,
              let targetPlayer = playerLookup(by: targetId) else {
            appendActionLog("\(actor.name) woke as Sailor but chose no player.", "\(actor.name) 作为水手醒来，但没有选择玩家。")
            return
        }
        let drunkPlayerId: UUID
        if targetId == actor.id {
            drunkPlayerId = actor.id
        } else {
            drunkPlayerId = [actor.id, targetId].randomElement() ?? actor.id
        }
        let drunkName = playerName(drunkPlayerId) ?? ui("Unknown", "未知玩家")
        setTemporaryDrunk(playerId: drunkPlayerId, untilDayNumber: currentDayNumber + 1, source: "sailor")
        appendActionLog("\(actor.name) chose \(targetPlayer.name). \(drunkName) is drunk until dusk.", "\(actor.name) 选择了 \(targetPlayer.name)。\(drunkName) 将醉酒至黄昏。")
        markPlayer(drunkPlayerId) { player in
            player.roleLog.append(ui("Made drunk by the Sailor until dusk.", "因水手效果醉酒至黄昏。"))
        }
    }

    func handleChambermaidAction(actor: PlayerCard, targets: [UUID]) {
        guard targets.count == 2 else {
            appendActionLog("\(actor.name) needs 2 players for the Chambermaid ability.", "\(actor.name) 需要选择 2 名玩家才能发动侍女能力。")
            return
        }
        let wakingCount = countWakingPlayers(for: targets)
        let targetNames = targets.compactMap(playerName).joined(separator: ", ")
        appendActionLog("\(actor.name) learned that \(wakingCount) of \(targetNames) woke tonight.", "\(actor.name) 得知 \(targetNames) 中有 \(wakingCount) 人今晚醒来。")
        markPlayer(actor.id) { player in
            player.roleLog.append(ui("Chambermaid result: \(wakingCount) of \(targetNames) woke tonight.", "侍女结果：\(targetNames) 中有 \(wakingCount) 人今晚醒来。"))
        }
    }

    func handleInnkeeperAction(actor: PlayerCard, targets: [UUID]) {
        guard targets.count == 2 else {
            appendActionLog("\(actor.name) needs 2 players for the Innkeeper ability.", "\(actor.name) 需要选择 2 名玩家才能发动店主能力。")
            return
        }
        for targetId in targets {
            setProtected(targetId, true, source: "innkeeper")
        }
        if let drunkTargetId = targets.randomElement() {
            setTemporaryDrunk(playerId: drunkTargetId, untilDayNumber: currentDayNumber + 1, source: "innkeeper")
            let drunkName = playerName(drunkTargetId) ?? ui("Unknown", "未知玩家")
            let targetNames = targets.compactMap(playerName).joined(separator: ", ")
            appendActionLog("\(actor.name) protected \(targetNames). \(drunkName) is drunk until dusk.", "\(actor.name) 保护了 \(targetNames)。\(drunkName) 将醉酒至黄昏。")
            markPlayer(drunkTargetId) { player in
                player.roleLog.append(ui("Made drunk by the Innkeeper until dusk.", "因店主效果醉酒至黄昏。"))
            }
        }
    }

    func handleGamblerAction(actor: PlayerCard, targets: [UUID], note: String) {
        guard let targetId = targets.first,
              let targetPlayer = playerLookup(by: targetId) else {
            appendActionLog("\(actor.name) woke as Gambler but chose no player.", "\(actor.name) 作为赌徒醒来，但没有选择玩家。")
            return
        }
        guard let guessedRoleId = parseRoleId(from: note),
              let guessedRole = roleTemplate(for: guessedRoleId) else {
            appendActionLog("\(actor.name) chose \(targetPlayer.name) but did not record a guessed character.", "\(actor.name) 选择了 \(targetPlayer.name)，但没有记录猜测角色。")
            return
        }
        let guessedRoleName = localizedRoleName(guessedRole)
        if targetPlayer.roleId == guessedRoleId {
            appendActionLog("\(actor.name) guessed \(guessedRoleName) for \(targetPlayer.name) and survived.", "\(actor.name) 猜测 \(targetPlayer.name) 是 \(guessedRoleName)，猜对并存活。")
        } else {
            killIfAlive(actor.id, reason: ui("Gambler loss", "赌徒猜错"))
            appendActionLog("\(actor.name) guessed \(guessedRoleName) for \(targetPlayer.name) and died.", "\(actor.name) 猜测 \(targetPlayer.name) 是 \(guessedRoleName)，猜错并死亡。")
        }
    }

    func handleCourtierAction(actor: PlayerCard, note: String) {
        if courtierUsedPlayerIds.contains(actor.id) {
            appendActionLog("\(actor.name) has already used the Courtier ability.", "\(actor.name) 已经使用过朝臣能力。")
            return
        }
        guard let selectedRoleId = parseRoleId(from: note),
              let selectedRole = roleTemplate(for: selectedRoleId) else {
            appendActionLog("\(actor.name) must enter a character for the Courtier ability.", "\(actor.name) 需要输入一个角色才能发动朝臣能力。")
            return
        }
        courtierUsedPlayerIds.insert(actor.id)
        setTemporaryDrunk(roleId: selectedRoleId, untilDayNumber: currentDayNumber + 3, source: "courtier")
        let roleName = localizedRoleName(selectedRole)
        appendActionLog("\(actor.name) chose \(roleName). All \(roleName) are drunk for 3 days and nights.", "\(actor.name) 选择了 \(roleName)。所有 \(roleName) 将醉酒 3 天 3 夜。")
    }

    func handleLunaticAction(actor: PlayerCard, targets: [UUID], note: String) {
        let targetNames = targets.compactMap(playerName).joined(separator: ", ")
        if targetNames.isEmpty {
            appendActionLog("\(actor.name) woke as Lunatic but chose no fake Demon target.", "\(actor.name) 作为疯子醒来，但没有选择假恶魔目标。")
            return
        }
        if note.isEmpty {
            appendActionLog("\(actor.name) chose \(targetNames) as the fake Demon target.", "\(actor.name) 选择了 \(targetNames) 作为假恶魔目标。")
        } else {
            appendActionLog("\(actor.name) chose \(targetNames) as the fake Demon target. \(note)", "\(actor.name) 选择了 \(targetNames) 作为假恶魔目标。\(note)")
        }
    }

    func revealRandomGoodPlayer(excluding excluded: Set<UUID> = []) -> PlayerCard? {
        players
            .filter { $0.alive && !excluded.contains($0.id) && isPlayerGood($0) }
            .randomElement()
    }

    func revealRandomAliveCharacter(excluding excluded: Set<UUID> = []) -> RoleTemplate? {
        players
            .filter { $0.alive && !excluded.contains($0.id) }
            .compactMap { roleTemplate(for: $0.roleId ?? "") }
            .randomElement()
    }

    func reviveIfDead(_ playerId: UUID, reason: String) {
        guard let index = players.firstIndex(where: { $0.id == playerId }), !players[index].alive else { return }
        players[index].alive = true
        players[index].deadReason = nil
        players[index].isDeadTonight = false
        players[index].roleLog.append(ui("Returned to life: \(reason)", "复活：\(reason)"))
        addLog("\(players[index].name) returned to life.", "\(players[index].name) 复活。")
    }

    func handleStewardAction(actor: PlayerCard) {
        guard let known = revealRandomGoodPlayer(excluding: [actor.id]) else {
            appendActionLog("\(actor.name) had no valid Steward result.", "\(actor.name) 没有有效的总管结果。")
            return
        }
        appendActionLog("\(actor.name) learned that \(known.name) is good.", "\(actor.name) 得知 \(known.name) 是善良玩家。")
        markPlayer(actor.id) { player in
            player.roleLog.append(ui("Learned that \(known.name) is good.", "得知 \(known.name) 是善良玩家。"))
        }
    }

    func handleNobleAction(actor: PlayerCard, targets: [UUID]) {
        let selectedPlayers = targets.compactMap { playerLookup(by: $0) }
        let names: String
        if selectedPlayers.count == 3 {
            names = selectedPlayers.shuffled().map(\.name).joined(separator: ", ")
        } else {
            let evilPlayers = players.filter { $0.alive && isPlayerEvil($0) && $0.id != actor.id }
            let goodPlayers = players.filter { $0.alive && isPlayerGood($0) && $0.id != actor.id }
            guard let evil = evilPlayers.randomElement(), goodPlayers.count >= 2 else {
                appendActionLog("\(actor.name) had no valid Noble trio.", "\(actor.name) 没有有效的贵族结果。")
                return
            }
            let trio = Array(goodPlayers.shuffled().prefix(2)) + [evil]
            names = trio.shuffled().map(\.name).joined(separator: ", ")
        }
        appendActionLog("\(actor.name) learned that exactly 1 of \(names) is evil.", "\(actor.name) 得知 \(names) 中恰有 1 人是邪恶。")
        markPlayer(actor.id) { player in
            player.roleLog.append(ui("Learned that exactly 1 of \(names) is evil.", "得知 \(names) 中恰有 1 人是邪恶。"))
        }
    }

    func handleKnightAction(actor: PlayerCard) {
        let candidates = players.filter { $0.alive && $0.id != actor.id && roleTemplate(for: $0.roleId ?? "")?.team != .demon }
        guard candidates.count >= 2 else {
            appendActionLog("\(actor.name) had no valid Knight result.", "\(actor.name) 没有有效的骑士结果。")
            return
        }
        let names = Array(candidates.shuffled().prefix(2)).map(\.name).joined(separator: ", ")
        appendActionLog("\(actor.name) learned that \(names) are not the Demon.", "\(actor.name) 得知 \(names) 不是恶魔。")
        markPlayer(actor.id) { player in
            player.roleLog.append(ui("Learned that \(names) are not the Demon.", "得知 \(names) 不是恶魔。"))
        }
    }

    func handleShugenjaAction(actor: PlayerCard) {
        let seated = orderedSeatedPlayers()
        guard let actorIndex = seated.firstIndex(where: { $0.id == actor.id }) else {
            appendActionLog("\(actor.name) had no valid Shugenja result.", "\(actor.name) 没有有效的修验者结果。")
            return
        }
        let clockwise = Array(seated.dropFirst(actorIndex + 1) + seated.prefix(actorIndex))
        let counterclockwise = Array(Array(seated[..<actorIndex].reversed()) + Array(seated.suffix(from: actorIndex + 1).reversed()))
        let clockwiseDistance = clockwise.firstIndex(where: { isPlayerEvil($0) }).map { $0 + 1 } ?? Int.max
        let counterDistance = counterclockwise.firstIndex(where: { isPlayerEvil($0) }).map { $0 + 1 } ?? Int.max
        let result: (String, String)
        if clockwiseDistance < counterDistance {
            result = ("clockwise", "顺时针")
        } else if counterDistance < clockwiseDistance {
            result = ("counterclockwise", "逆时针")
        } else {
            result = ("either direction", "任一方向")
        }
        appendActionLog("\(actor.name) learned the nearest evil is \(result.0).", "\(actor.name) 得知最近的邪恶位于\(result.1)。")
        markPlayer(actor.id) { player in
            player.roleLog.append(ui("Nearest evil: \(result.0).", "最近的邪恶在\(result.1)。"))
        }
    }

    func pixieAvailableRoles() -> [RoleTemplate] {
        let inPlayTownsfolk = players
            .filter { $0.alive && $0.roleId != "pixie" }
            .compactMap { $0.roleId.flatMap { roleTemplate(for: $0) } }
            .filter { $0.team == .townsfolk }
        var seen = Set<String>()
        return inPlayTownsfolk.filter { seen.insert($0.id).inserted }
    }

    func handlePixieAction(actor: PlayerCard, note: String) {
        let role: RoleTemplate?
        if !note.isEmpty, let selected = roleTemplate(for: note), selected.team == .townsfolk {
            role = selected
        } else {
            let townsfolk = players.filter { $0.id != actor.id && $0.alive && roleTemplate(for: $0.roleId ?? "")?.team == .townsfolk }
            role = townsfolk.randomElement().flatMap { roleTemplate(for: $0.roleId ?? "") }
        }
        guard let role else {
            appendActionLog("\(actor.name) had no valid Pixie result.", "\(actor.name) 没有有效的小精灵结果。")
            return
        }
        pixieLearnedRoleByPlayerId[actor.id] = role.id
        let roleName = localizedRoleName(role)
        appendActionLog("\(actor.name) learned an in-play Townsfolk: \(roleName).", "\(actor.name) 得知一名在场镇民：\(roleName)。")
        markPlayer(actor.id) { player in
            player.roleLog.append(ui("Learned the in-play Townsfolk \(roleName).", "得知在场镇民 \(roleName)。"))
        }
    }

    func handleHighPriestessAction(actor: PlayerCard) {
        let candidate = players
            .filter { $0.alive && $0.id != actor.id }
            .sorted {
                let leftPriority = doesPlayerWakeTonightDueToOwnAbility($0) ? 0 : 1
                let rightPriority = doesPlayerWakeTonightDueToOwnAbility($1) ? 0 : 1
                if leftPriority != rightPriority { return leftPriority < rightPriority }
                return $0.seatNumber < $1.seatNumber
            }
            .first
        guard let candidate else {
            appendActionLog("\(actor.name) had no High Priestess lead tonight.", "\(actor.name) 今夜没有女祭司引导结果。")
            return
        }
        appendActionLog("\(actor.name) was guided to \(candidate.name).", "\(actor.name) 被引导至 \(candidate.name)。")
        markPlayer(actor.id) { player in
            player.roleLog.append(ui("Was guided to \(candidate.name).", "被引导至 \(candidate.name)。"))
        }
    }

    func handleKingAction(actor: PlayerCard) {
        guard let shownRole = revealRandomAliveCharacter(excluding: [actor.id]) else {
            appendActionLog("\(actor.name) had no King result tonight.", "\(actor.name) 今夜没有国王结果。")
            return
        }
        let roleName = localizedRoleName(shownRole)
        appendActionLog("\(actor.name) learned an alive character: \(roleName).", "\(actor.name) 得知一个存活角色：\(roleName)。")
        markPlayer(actor.id) { player in
            player.roleLog.append(ui("Learned an alive character: \(roleName).", "得知一个存活角色：\(roleName)。"))
        }
    }

    func handleChoirboyAction(actor: PlayerCard) {
        guard let demon = players.first(where: { $0.alive && roleTemplate(for: $0.roleId ?? "")?.team == .demon }) else {
            appendActionLog("\(actor.name) had no Choirboy result.", "\(actor.name) 没有有效的唱诗班男孩结果。")
            return
        }
        appendActionLog("\(actor.name) learned that \(demon.name) is the Demon.", "\(actor.name) 得知 \(demon.name) 是恶魔。")
        markPlayer(actor.id) { player in
            player.roleLog.append(ui("Learned that \(demon.name) is the Demon.", "得知 \(demon.name) 是恶魔。"))
        }
        kingKilledByDemonPlayerId = nil
    }

    func handleAcrobatAction(actor: PlayerCard, targets: [UUID]) {
        guard let target = targets.first, let targetPlayer = playerLookup(by: target) else {
            appendActionLog("\(actor.name) woke as Acrobat but chose no player.", "\(actor.name) 作为杂技演员醒来，但没有选择玩家。")
            return
        }
        acrobatTrackedPlayerIds[actor.id] = targetPlayer.id
        appendActionLog("\(actor.name) is watching \(targetPlayer.name) for poison or drunkenness.", "\(actor.name) 正在观察 \(targetPlayer.name) 是否中毒或醉酒。")
    }

    func handleFearmongerAction(actor: PlayerCard, targets: [UUID]) {
        guard let target = targets.first, let targetPlayer = playerLookup(by: target) else {
            appendActionLog("\(actor.name) woke as Fearmonger but chose no target.", "\(actor.name) 作为恐惧贩子醒来，但没有选择目标。")
            return
        }
        fearmongerTargetByPlayerId[actor.id] = targetPlayer.id
        appendActionLog("\(actor.name) chose \(targetPlayer.name) as the Fearmonger target.", "\(actor.name) 选择 \(targetPlayer.name) 作为恐惧贩子的目标。")
    }

    func handleHarpyAction(actor: PlayerCard, targets: [UUID]) {
        guard targets.count == 2,
              let madPlayer = playerLookup(by: targets[0]),
              let accusedPlayer = playerLookup(by: targets[1]) else {
            appendActionLog("\(actor.name) needs 2 players for the Harpy ability.", "\(actor.name) 需要 2 名玩家才能发动鹰身女妖能力。")
            return
        }
        harpyMadPlayerId = madPlayer.id
        harpyAccusedPlayerId = accusedPlayer.id
        appendActionLog("\(actor.name) made \(madPlayer.name) mad that \(accusedPlayer.name) is evil.", "\(actor.name) 让 \(madPlayer.name) 明天必须坚称 \(accusedPlayer.name) 是邪恶。")
        markPlayer(madPlayer.id) { player in
            player.roleLog.append(ui("Harpy madness: insist that \(accusedPlayer.name) is evil.", "鹰身女妖疯狂：必须坚称 \(accusedPlayer.name) 是邪恶。"))
        }
    }

    func handleAlchemistAction(actor: PlayerCard, note: String) {
        guard let minionRoleId = parseRoleId(from: note),
              let role = roleTemplate(for: minionRoleId),
              role.team == .minion else {
            appendActionLog("\(actor.name) needs a Minion ability for the Alchemist.", "\(actor.name) 需要为炼金术士输入一个爪牙能力。")
            return
        }
        alchemistGrantedAbilityRoleId = minionRoleId
        let roleName = localizedRoleName(role)
        appendActionLog("\(actor.name) gained the \(roleName) ability as the Alchemist.", "\(actor.name) 作为炼金术士获得了 \(roleName) 能力。")
    }

    func handleBoffinAction(actor: PlayerCard, note: String) {
        guard let grantedRoleId = parseRoleId(from: note),
              let role = roleTemplate(for: grantedRoleId),
              role.team == .townsfolk || role.team == .outsider else {
            appendActionLog("\(actor.name) needs a good-character ability for Boffin.", "\(actor.name) 需要为博芬输入一个善良角色能力。")
            return
        }
        boffinGrantedAbilityRoleId = grantedRoleId
        let roleName = localizedRoleName(role)
        appendActionLog("\(actor.name) granted the Demon the \(roleName) ability.", "\(actor.name) 让恶魔获得了 \(roleName) 能力。")
    }

    func handleMezephelesAction(actor: PlayerCard, note: String) {
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            appendActionLog("\(actor.name) needs a secret word for Mezepheles.", "\(actor.name) 需要为梅泽菲勒斯输入秘密单词。")
            return
        }
        appendActionLog("\(actor.name) set the Mezepheles word: \(trimmed).", "\(actor.name) 设定了梅泽菲勒斯单词：\(trimmed)。")
    }

    func handleAlHadikhiaAction(actor: PlayerCard, targets: [UUID], note: String) {
        guard targets.count == 3 else {
            appendActionLog("\(actor.name) needs 3 players for Al-Hadikhia.", "\(actor.name) 需要选择 3 名玩家才能发动阿尔哈迪基亚能力。")
            return
        }
        let decisions = note
            .split(whereSeparator: { [",", "，", "/", " "].contains($0) })
            .map { $0.lowercased() }
        let normalizedDecisions = decisions.count == 3 ? decisions : Array(repeating: "live", count: 3)
        for (index, targetId) in targets.enumerated() {
            let chooseDie = normalizedDecisions[index].hasPrefix("d") || normalizedDecisions[index].contains("死")
            if chooseDie {
                killByDemonIfAlive(targetId, reason: ui("Al-Hadikhia choice", "阿尔哈迪基亚抉择"))
            } else {
                reviveIfDead(targetId, reason: ui("Al-Hadikhia choice", "阿尔哈迪基亚抉择"))
            }
        }
        let allAlive = targets.allSatisfy { playerLookup(by: $0)?.alive == true }
        if allAlive {
            for targetId in targets {
                killByDemonIfAlive(targetId, reason: ui("Al-Hadikhia all lived", "阿尔哈迪基亚全员求生"))
            }
        }
        let targetNames = targets.compactMap(playerName).joined(separator: ", ")
        appendActionLog("\(actor.name) resolved Al-Hadikhia on \(targetNames).", "\(actor.name) 对 \(targetNames) 结算了阿尔哈迪基亚能力。")
    }

    func handleOjoAction(actor: PlayerCard, note: String) {
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            appendActionLog("\(actor.name) chose no character for Ojo.", "\(actor.name) 没有为奥霍选择角色。")
            return
        }
        let rolePart = trimmed.components(separatedBy: "->").first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? trimmed
        let explicitPlayerPart = trimmed.contains("->")
            ? trimmed.components(separatedBy: "->").last?.trimmingCharacters(in: .whitespacesAndNewlines)
            : nil
        let targetId = explicitPlayerPart.flatMap { name in
            players.first(where: { $0.name.lowercased() == name.lowercased() })?.id
        } ?? parseRoleId(from: rolePart).flatMap { roleId in
            players.filter { $0.alive && $0.roleId == roleId }.randomElement()?.id
        }
        if let targetId {
            killByDemonIfAlive(targetId, reason: ui("Ojo guess", "奥霍猜测"))
            appendActionLog("\(actor.name) chose \(trimmed) for Ojo and killed \(playerName(targetId) ?? "a player").", "\(actor.name) 以奥霍能力选择了 \(trimmed)，并杀死了 \(playerName(targetId) ?? "一名玩家")。")
        } else {
            appendActionLog("\(actor.name) chose \(trimmed) for Ojo, but no matching player died.", "\(actor.name) 以奥霍能力选择了 \(trimmed)，但没有匹配玩家死亡。")
        }
    }

    func handleYaggababbleAction(actor: PlayerCard, note: String) {
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        if let target = players.first(where: { $0.alive && trimmed.lowercased().contains($0.name.lowercased()) }) {
            killByDemonIfAlive(target.id, reason: ui("Yaggababble phrase", "亚嘎巴布尔短语"))
            appendActionLog("\(actor.name) caused \(target.name) to die to Yaggababble.", "\(actor.name) 让 \(target.name) 因亚嘎巴布尔而死亡。")
        } else if trimmed.isEmpty {
            appendActionLog("\(actor.name) recorded no Yaggababble phrase tonight.", "\(actor.name) 今夜没有记录亚嘎巴布尔短语。")
        } else {
            appendActionLog("\(actor.name) recorded the Yaggababble phrase: \(trimmed).", "\(actor.name) 记录了亚嘎巴布尔短语：\(trimmed)。")
        }
    }

    func handleCultLeaderNight(actor: PlayerCard) {
        let neighbors = aliveNeighbors(of: actor)
        guard neighbors.count == 2 else {
            appendActionLog("\(actor.name) had no Cult Leader alignment change.", "\(actor.name) 今夜邪教领袖没有发生阵营变化。")
            return
        }
        let leftIsEvil = isPlayerEvil(neighbors[0])
        let rightIsEvil = isPlayerEvil(neighbors[1])
        let previous = isPlayerEvil(actor)
        if leftIsEvil == rightIsEvil {
            alignmentOverrides[actor.id] = leftIsEvil
            if previous != leftIsEvil {
                appendActionLog("\(actor.name) became \(leftIsEvil ? "evil" : "good") as the Cult Leader.", "\(actor.name) 作为邪教领袖转为\(leftIsEvil ? "邪恶" : "善良")。")
            } else {
                appendActionLog("\(actor.name) remained \(leftIsEvil ? "evil" : "good") as the Cult Leader.", "\(actor.name) 作为邪教领袖仍为\(leftIsEvil ? "邪恶" : "善良")。")
            }
        } else {
            appendActionLog("\(actor.name) had mixed neighbors as the Cult Leader.", "\(actor.name) 作为邪教领袖时两侧邻座阵营不同。")
        }
    }

    func handleEngineerChange(note: String, actor: PlayerCard) {
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            appendActionLog("\(actor.name) needs a Demon or Minion role list for Engineer.", "\(actor.name) 需要为工程师输入恶魔或爪牙角色。")
            return
        }
        engineerUsedPlayerIds.insert(actor.id)
        let roleIds = trimmed
            .split(whereSeparator: { [",", "，", "/", " "].contains($0) })
            .compactMap { parseRoleId(from: String($0)) }
        if roleIds.count == 1,
           let newDemonId = roleIds.first,
           roleTemplate(for: newDemonId)?.team == .demon,
           let demonIndex = players.firstIndex(where: { $0.alive && roleTemplate(for: $0.roleId ?? "")?.team == .demon }) {
            players[demonIndex].roleId = newDemonId
            appendActionLog("\(actor.name) changed the Demon to \(localizedRoleName(roleTemplate(for: newDemonId))).", "\(actor.name) 将恶魔改为 \(localizedRoleName(roleTemplate(for: newDemonId)))。")
            return
        }
        let minionIds = roleIds.filter { roleTemplate(for: $0)?.team == .minion }
        let minionIndexes = players.indices.filter { players[$0].alive && roleTemplate(for: players[$0].roleId ?? "")?.team == .minion }
        guard !minionIds.isEmpty, minionIds.count == minionIndexes.count else {
            appendActionLog("\(actor.name) recorded an Engineer change: \(trimmed).", "\(actor.name) 记录了一次工程师改动：\(trimmed)。")
            return
        }
        for (index, roleId) in zip(minionIndexes, minionIds) {
            players[index].roleId = roleId
        }
        appendActionLog("\(actor.name) changed the Minions to \(minionIds.compactMap { localizedRoleName(roleTemplate(for: $0)) }.joined(separator: ", ")).", "\(actor.name) 将爪牙改为 \(minionIds.compactMap { localizedRoleName(roleTemplate(for: $0)) }.joined(separator: "、"))。")
    }

    func handleSummonerAction(actor: PlayerCard, targets: [UUID], note: String) {
        guard let targetId = targets.first,
              let targetIndex = players.firstIndex(where: { $0.id == targetId }) else {
            appendActionLog("\(actor.name) needs a player target for the Summoner.", "\(actor.name) 需要为召唤师选择一名玩家。")
            return
        }
        let demonText = note.components(separatedBy: "->").first ?? note
        let demonId = parseRoleId(from: demonText)
        guard let demonId, roleTemplate(for: demonId)?.team == .demon else {
            appendActionLog("\(actor.name) must enter a Demon for the Summoner ability.", "\(actor.name) 需要为召唤师输入一个恶魔角色。")
            return
        }
        players[targetIndex].roleId = demonId
        alignmentOverrides[players[targetIndex].id] = true
        appendActionLog("\(actor.name) summoned \(players[targetIndex].name) as \(localizedRoleName(roleTemplate(for: demonId))).", "\(actor.name) 将 \(players[targetIndex].name) 召唤为 \(localizedRoleName(roleTemplate(for: demonId)))。")
    }

    func toggleNightTarget(_ playerID: UUID) {
        let limit = currentNightTargetLimit()
        guard limit > 0 else { return }
        if currentNightTargets.contains(playerID) {
            currentNightTargets.removeAll(where: { $0 == playerID })
            return
        }
        if limit == 1 {
            currentNightTargets = [playerID]
        } else if currentNightTargets.count < limit {
            currentNightTargets.append(playerID)
        }
    }

    func clearNightSelection() {
        currentNightTargets.removeAll()
        currentNightNote = ""
        currentNightAlignmentSelections.removeAll()
    }

    func completeCurrentNightAction() {
        guard let step = currentNightStep, let actor = currentNightActor else { return }
        let roleId = step.roleId
        let targets = currentNightTargets
        let names = targets.compactMap { id in playerLookup(by: id)?.name }
        let targetText = names.joined(separator: ", ")
        let note = currentNightNote.trimmingCharacters(in: .whitespacesAndNewlines)
        var recordTargets = targets
        var recordTargetText = targetText
        var recordNote = note

        if isDisplayedDrunk(actor, actingAs: roleId) {
            handleDisplayedDrunkNightAction(
                actor: actor,
                roleId: roleId,
                targets: targets,
                targetText: targetText,
                note: note
            )
            appendRoleRecord(
                for: actor.id,
                text: currentLogLine(for: actor, roleId: roleId, targetText: recordTargetText, note: recordNote),
                toneOverride: currentActionLogToneOverride
            )
            appendNightActionRecord(actor: actor.id, roleId: roleId, targets: recordTargets, note: recordNote)
            currentActionLogToneOverride = nil
            proceedToNextNightStep()
            return
        }

        if isAbilitySuppressed(actor) && roleId != "poisoner" {
            if roleTemplate(for: roleId)?.needsNightResultInput == true {
                // Info role: let Storyteller give false info and color it as poison.
                currentActionLogToneOverride = .poison
            } else {
                // Active role: skip ability and color the failure as poison.
                addLog(
                    ui("\(actor.name) is poisoned — ability has no effect.", "\(actor.name) 今夜中毒——能力无效。"),
                    toneOverride: .poison
                )
                appendRoleRecord(
                    for: actor.id,
                    text: ui("\(actor.name) skipped \(localizedRoleName(roleTemplate(for: roleId))) because of poison.", "\(actor.name) 因中毒跳过了 \(localizedRoleName(roleTemplate(for: roleId)))。"),
                    toneOverride: .poison
                )
                appendNightActionRecord(actor: actor.id, roleId: roleId, targets: targets, note: "poisoned")
                proceedToNextNightStep()
                return
            }
        }

        switch roleId {
        case "alchemist":
            handleAlchemistAction(actor: actor, note: note)
        case "acrobat":
            handleAcrobatAction(actor: actor, targets: targets)
        case "steward":
            handleStewardAction(actor: actor)
        case "noble":
            handleNobleAction(actor: actor, targets: targets)
        case "knight":
            handleKnightAction(actor: actor)
        case "shugenja":
            handleShugenjaAction(actor: actor)
        case "pixie":
            handlePixieAction(actor: actor, note: note)
        case "highpriestess":
            handleHighPriestessAction(actor: actor)
        case "king":
            handleKingAction(actor: actor)
        case "choirboy":
            handleChoirboyAction(actor: actor)
        case "boffin":
            handleBoffinAction(actor: actor, note: note)
        case "grandmother":
            handleGrandmotherAction(actor: actor, targets: targets, shownRoleId: note)
        case "sailor":
            handleSailorAction(actor: actor, targets: targets)
        case "chambermaid":
            handleChambermaidAction(actor: actor, targets: targets)
        case "fearmonger":
            handleFearmongerAction(actor: actor, targets: targets)
        case "exorcist":
            if let target = targets.first,
               let targetPlayer = playerLookup(by: target),
               roleTemplate(for: targetPlayer.roleId ?? "")?.team == .demon {
                exorcisedPlayerId = targetPlayer.id
                appendActionLog("\(actor.name) blocked \(targetPlayer.name)'s Demon action.", "\(actor.name) 阻止了 \(targetPlayer.name) 的恶魔行动。")
            } else if let target = targets.first {
                appendActionLog("\(actor.name) chose \(playerName(target) ?? "a player"), but they were not the Demon.", "\(actor.name) 选择了 \(playerName(target) ?? "一名玩家")，但其不是恶魔。")
            }
        case "innkeeper":
            handleInnkeeperAction(actor: actor, targets: targets)
        case "gambler":
            handleGamblerAction(actor: actor, targets: targets, note: note)
        case "courtier":
            handleCourtierAction(actor: actor, note: note)
        case "washerwoman", "librarian", "investigator":
            handleTroubleBrewingFirstNightInfo(actor: actor, roleId: roleId, targets: targets, note: note)
        case "professor":
            if let target = targets.first,
               let targetPlayer = playerLookup(by: target),
               !targetPlayer.alive,
               roleTemplate(for: targetPlayer.roleId ?? "")?.team == .townsfolk {
                professorUsedPlayerIds.insert(actor.id)
                markPlayer(target) { player in
                    player.alive = true
                    player.deadReason = nil
                    player.isDeadTonight = false
                    player.roleLog.append(ui("Returned to life by the Professor.", "被教授复活。"))
                }
                appendActionLog("\(actor.name) revived \(targetPlayer.name).", "\(actor.name) 复活了 \(targetPlayer.name)。")
            } else if let target = targets.first {
                appendActionLog("\(actor.name) could not revive \(playerName(target) ?? "that player").", "\(actor.name) 无法复活 \(playerName(target) ?? "该玩家")。")
            }
        case "devils-advocate":
            devilsAdvocateProtectedPlayerId = targets.first
            appendActionLog("\(actor.name) protected \(targetText) from tomorrow's execution.", "\(actor.name) 保护 \(targetText) 免于明日处决死亡。")
        case "cultleader":
            handleCultLeaderNight(actor: actor)
        case "huntsman":
            huntsmanUsedPlayerIds.insert(actor.id)
            if let target = targets.first, let targetPlayer = playerLookup(by: target) {
                appendActionLog("\(actor.name) chose \(targetPlayer.name) for the Huntsman ability.", "\(actor.name) 选择 \(targetPlayer.name) 作为猎人目标。")
            } else {
                appendActionLog("\(actor.name) chose not to use the Huntsman ability.", "\(actor.name) 没有使用猎人能力。")
            }
        case "lunatic":
            handleLunaticAction(actor: actor, targets: targets, note: note)
        case "harpy":
            handleHarpyAction(actor: actor, targets: targets)
        case "witch":
            witchCursedPlayerId = targets.first
            appendActionLog("\(actor.name) cursed \(targetText).", "\(actor.name) 诅咒了 \(targetText)。")
        case "assassin":
            if !assassinUsedPlayerIds.contains(actor.id), let target = targets.first {
                assassinUsedPlayerIds.insert(actor.id)
                killIfAlive(target, reason: ui("Assassin attack", "刺客击杀"))
                appendActionLog("\(actor.name) assassinated \(targetText).", "\(actor.name) 刺杀了 \(targetText)。")
            } else if assassinUsedPlayerIds.contains(actor.id) {
                appendActionLog("\(actor.name) has already used the Assassin ability.", "\(actor.name) 已经使用过刺客技能。")
            }
        case "godfather":
            if outsiderExecutedToday, let target = targets.first {
                resolveForcedNightKill(target)
                appendActionLog("\(actor.name) chose \(targetText) for the Godfather kill.", "\(actor.name) 选择 \(targetText) 作为教父夜杀目标。")
            } else {
                appendActionLog("\(actor.name) had no Godfather kill tonight.", "\(actor.name) 今夜教父没有额外击杀。")
            }
        case "nightwatchman":
            nightwatchmanUsedPlayerIds.insert(actor.id)
            if let target = targets.first,
               let targetPlayer = playerLookup(by: target) {
                markPlayer(targetPlayer.id) { player in
                    player.roleLog.append(ui("The Nightwatchman confirmed themselves to you.", "守夜人向你确认了自己的身份。"))
                }
                appendActionLog("\(actor.name) confirmed to \(targetPlayer.name) as the Nightwatchman.", "\(actor.name) 向 \(targetPlayer.name) 确认了自己是守夜人。")
                markPlayer(actor.id) { player in
                    player.roleLog.append(ui("Confirmed to \(targetPlayer.name) as the Nightwatchman.", "向 \(targetPlayer.name) 确认了自己是守夜人。"))
                }
            } else {
                appendActionLog("\(actor.name) woke as Nightwatchman but chose no player.", "\(actor.name) 作为守夜人醒来，但没有选择玩家。")
            }
        case "bountyhunter":
            if let learned = bountyHunterRevealPlayer() {
                let alignmentText = ui("evil", "邪恶")
                appendActionLog("\(actor.name) learned that \(learned.name) is \(alignmentText).", "\(actor.name) 得知 \(learned.name) 是\(alignmentText)玩家。")
                markPlayer(actor.id) { player in
                    player.roleLog.append(ui("Learned that \(learned.name) is evil.", "得知 \(learned.name) 是邪恶玩家。"))
                }
            } else {
                appendActionLog("\(actor.name) had no new evil player to learn.", "\(actor.name) 今夜没有新的邪恶玩家可获知。")
            }
        case "balloonist":
            if let shown = balloonistRevealPlayer(suppressed: isAbilitySuppressed(actor)),
               let shownRole = roleTemplate(for: shown.roleId ?? "") {
                let typeName = localizedTeamName(shownRole.team)
                appendActionLog("\(actor.name) learned a \(typeName): \(shown.name).", "\(actor.name) 得知一名\(typeName)：\(shown.name)。")
                markPlayer(actor.id) { player in
                    player.roleLog.append(ui("Learned a \(typeName): \(shown.name).", "得知一名\(typeName)：\(shown.name)。"))
                }
            } else {
                appendActionLog("\(actor.name) had no valid Balloonist result tonight.", "\(actor.name) 今夜没有有效的气球师结果。")
            }
        case "general":
            let result = generalAlignmentResult()
            appendActionLog("\(actor.name) learned: \(result.english).", "\(actor.name) 得知：\(result.chinese)。")
            markPlayer(actor.id) { player in
                player.roleLog.append(ui("General result: \(result.english).", "将军结果：\(result.chinese)。"))
            }
        case "mezepheles":
            handleMezephelesAction(actor: actor, note: note)
        case "organgrinder":
            appendActionLog("\(actor.name) resolved Organ Grinder secrecy. \(note)", "\(actor.name) 结算了风琴师的秘密投票效果。\(note)")
        case "villageidiot":
            if let target = targets.first,
               let targetPlayer = playerLookup(by: target) {
                let result = villageIdiotResult(for: targetPlayer)
                appendActionLog("\(actor.name) learned that \(targetPlayer.name) is \(result.english).", "\(actor.name) 得知 \(targetPlayer.name) 是\(result.chinese)阵营。")
                markPlayer(actor.id) { player in
                    player.roleLog.append(ui("Village Idiot learned \(targetPlayer.name) is \(result.english).", "村中傻子得知 \(targetPlayer.name) 是\(result.chinese)阵营。"))
                }
            } else {
                appendActionLog("\(actor.name) woke as Village Idiot but chose no player.", "\(actor.name) 作为村中傻子醒来，但没有选择玩家。")
            }
        case "poisoner":
            poisonerPoisonedPlayerId = targets.first
            poisonerPoisonSourcePlayerId = actor.id
            for target in targets { setPoisoned(target, true) }
            appendActionLog("\(actor.name) poisoned \(targetText).", "\(actor.name) 对 \(targetText) 施加了中毒。")
        case "widow":
            widowPoisonedPlayerId = targets.first
            widowKnownPlayerId = nil
            if let target = targets.first {
                if target != actor.id,
                   let witness = players
                    .filter({ $0.alive && $0.id != actor.id })
                    .filter({ isPlayerGood($0) })
                    .randomElement() {
                    widowKnownPlayerId = witness.id
                    markPlayer(witness.id) { player in
                        player.roleLog.append(ui("Learned that a Widow is in play.", "得知本局有寡妇在场。"))
                    }
                    appendActionLog("\(actor.name) poisoned \(targetText). \(witness.name) learns a Widow is in play.", "\(actor.name) 对 \(targetText) 施加了中毒。\(witness.name) 得知本局有寡妇在场。")
                } else {
                    appendActionLog("\(actor.name) poisoned \(targetText).", "\(actor.name) 对 \(targetText) 施加了中毒。")
                }
            } else {
                appendActionLog("\(actor.name) woke as Widow but chose no poisoned player.", "\(actor.name) 作为寡妇醒来，但没有选择中毒目标。")
            }
        case "monk":
            for target in targets { setProtected(target, true, source: "monk") }
            appendActionLog("\(actor.name) protected \(targetText).", "\(actor.name) 保护了 \(targetText)。")
        case "butler":
            if let target = targets.first {
                setButlerMaster(actor.id, master: target)
                appendActionLog("\(actor.name) chose \(playerName(target) ?? "an unknown player") as master.", "\(actor.name) 选择了 \(playerName(target) ?? "一名未知玩家") 作为主人。")
            } else {
                appendActionLog("\(actor.name) woke with no master selected.", "\(actor.name) 醒来但没有选择主人。")
            }
        case "imp":
            guard let target = targets.first else {
                appendActionLog("\(actor.name) used the Imp ability but no target was chosen.", "\(actor.name) 发动小恶魔能力但没有选择目标。")
                break
            }
            if target == actor.id {
                killIfAlive(actor.id, reason: ui("Imp suicide", "小恶魔自杀"))
                appendActionLog("\(actor.name) chose self and died by Imp suicide.", "\(actor.name) 选择了自己并以小恶魔自杀结算死亡。")
                prepareImpReplacementSelection()
            } else {
                resolveDemonKill(target)
                appendActionLog("\(actor.name) chose a night kill target: \(targetText).", "\(actor.name) 选择了夜杀目标：\(targetText)。")
            }
        case "lleech":
            if isFirstNightPhase {
                lleechHostPlayerId = targets.first
                if targets.first != nil {
                    appendActionLog("\(actor.name) chose \(targetText) as the Lleech host.", "\(actor.name) 选择 \(targetText) 作为利奇宿主。")
                } else {
                    appendActionLog("\(actor.name) woke as Lleech but chose no host.", "\(actor.name) 作为利奇醒来，但没有选择宿主。")
                }
            } else if let target = targets.first {
                resolveDemonKill(target)
                appendActionLog("\(actor.name) chose a Lleech kill target: \(targetText).", "\(actor.name) 选择了利奇夜杀目标：\(targetText)。")
            } else {
                appendActionLog("\(actor.name) woke as Lleech but chose no victim.", "\(actor.name) 作为利奇醒来，但没有选择击杀目标。")
            }
        case "lycanthrope":
            if let target = targets.first,
               let targetPlayer = playerLookup(by: target),
               targetPlayer.alive {
                let isGoodTarget = isPlayerGood(targetPlayer)
                if isGoodTarget {
                    demonKillBlockedTonight = true
                    killIfAlive(target, reason: ui("Lycanthrope attack", "狼人击杀"))
                    appendActionLog("\(actor.name) killed \(targetText). The Demon does not kill tonight.", "\(actor.name) 杀死了 \(targetText)。今夜恶魔不会杀人。")
                } else {
                    appendActionLog("\(actor.name) targeted \(targetText), but they were not good.", "\(actor.name) 选择了 \(targetText)，但目标不是善良玩家。")
                }
            } else {
                appendActionLog("\(actor.name) woke as Lycanthrope but chose no target.", "\(actor.name) 作为狼人醒来，但没有选择目标。")
            }
        case "preacher":
            if let target = targets.first,
               let targetPlayer = playerLookup(by: target),
               roleTemplate(for: targetPlayer.roleId ?? "")?.team == .minion {
                preachedMinionIds.insert(targetPlayer.id)
                appendActionLog("\(actor.name) preached to \(targetPlayer.name).", "\(actor.name) 向 \(targetPlayer.name) 布道，令其失去能力。")
                markPlayer(targetPlayer.id) { player in
                    player.roleLog.append(ui("The Preacher chose you. You have no ability while the Preacher is alive and healthy.", "传教士选择了你。只要传教士存活且能力正常，你便失去能力。"))
                }
            } else if let target = targets.first,
                      let targetPlayer = playerLookup(by: target) {
                appendActionLog("\(actor.name) preached to \(targetPlayer.name), but they were not a Minion.", "\(actor.name) 向 \(targetPlayer.name) 布道，但其不是爪牙。")
            } else {
                appendActionLog("\(actor.name) woke as Preacher but chose no player.", "\(actor.name) 作为传教士醒来，但没有选择玩家。")
            }
        case "ravenkeeper":
            if let target = targets.first,
               let targetPlayer = playerLookup(by: target) {
                let shownRole: RoleTemplate?
                if shouldUseFullRolePoolForExactReveal(roleId: roleId) {
                    shownRole = roleTemplate(for: note)
                } else {
                    shownRole = resolvedExactRevealRole(for: targetPlayer, selectedRoleId: note)
                }
                guard let shownRole else {
                    appendActionLog(
                        "\(actor.name) inspected \(targetPlayer.name), but the storyteller still needs to choose the shown role.",
                        "\(actor.name) 查看了 \(targetPlayer.name)，但说书人仍需选择要展示的角色。"
                    )
                    break
                }
                let shownRoleName = localizedRoleName(shownRole)
                recordTargets = [target]
                recordTargetText = targetPlayer.name
                recordNote = shownRole.id
                appendActionLog("\(actor.name) learned that \(targetPlayer.name) is the \(shownRoleName).", "\(actor.name) 得知 \(targetPlayer.name) 的角色是 \(shownRoleName)。")
                markPlayer(actor.id) { player in
                    player.roleLog.append(ui("Learned that \(targetPlayer.name) is the \(shownRoleName).", "得知 \(targetPlayer.name) 的角色是 \(shownRoleName)。"))
                }
            } else {
                appendActionLog("Ravenkeeper woke but had no target.", "守鸦人醒来但没有目标。")
            }
        case "undertaker":
            if let result = undertakerExecutionResult(selectedRoleId: note) {
                recordTargets = [result.player.id]
                recordTargetText = result.player.name
                recordNote = result.role.id
                appendActionLog(
                    ui(
                        "Undertaker learned that \(result.player.name) registered as the \(localizedRoleName(result.role)).",
                        "送葬者得知 \(result.player.name) 登记为 \(localizedRoleName(result.role))。"
                    )
                )
                markPlayer(actor.id) { player in
                    player.roleLog.append(
                        ui(
                            "Learned that \(result.player.name) registered as the \(localizedRoleName(result.role)).",
                            "得知 \(result.player.name) 登记为 \(localizedRoleName(result.role))。"
                        )
                    )
                }
            } else {
                appendActionLog("Undertaker had no execution to inspect.", "送葬者今晚没有可查看的处决结果。")
            }
        case "oracle":
            let deadEvil = players.filter { !$0.alive && isPlayerEvil($0) }.count
            appendActionLog("Oracle learned that \(deadEvil) dead player(s) are evil.", "神谕者得知有 \(deadEvil) 名死者是邪恶。")
        case "flowergirl":
            appendActionLog(
                ui(
                    "Flowergirl learned that the Demon \(demonVotedTodayFlag ? "did" : "did not") vote today.",
                    "卖花女得知恶魔今天\(demonVotedTodayFlag ? "投了票" : "没有投票")。"
                )
            )
        case "town-crier":
            appendActionLog(
                ui(
                    "Town Crier learned that a Minion \(minionNominatedTodayFlag ? "did" : "did not") nominate today.",
                    "传令官得知今天\(minionNominatedTodayFlag ? "有" : "没有")爪牙发起提名。"
                )
            )
        case "seamstress":
            if targets.count == 2,
               let first = playerLookup(by: targets[0]),
               let second = playerLookup(by: targets[1]) {
                seamstressUsedPlayerIds.insert(actor.id)
                let sameAlignment = detectedIsEvil(first) == detectedIsEvil(second)
                appendActionLog("Seamstress learned \(first.name) and \(second.name) are \(sameAlignment ? "the same" : "different") alignment.", "裁缝得知 \(first.name) 与 \(second.name) 的阵营\(sameAlignment ? "相同" : "不同")。")
            } else {
                appendActionLog("Seamstress needs 2 players to compare alignments.", "裁缝需要选择 2 名玩家才能比较阵营。")
            }
        case "juggler":
            jugglerResolvedPlayerIds.insert(actor.id)
            let guesses = jugglerGuessesByPlayerId[actor.id] ?? ui("no guesses recorded", "没有记录猜测")
            let resultText = note.isEmpty ? ui("No result entered.", "未输入结果。") : note
            appendActionLog(
                ui(
                    "Juggler result for \(actor.name): \(resultText) | guesses: \(guesses)",
                    "\(actor.name) 的杂耍演员结果：\(resultText)｜猜测：\(guesses)"
                )
            )
        case "fortuneteller":
            appendActionLog("Fortune Teller checked \(targetText). \(note)", "占卜师查看了 \(targetText)。\(note)")
        case "empath":
            appendActionLog("Empath reported: \(note)", "共情者结果：\(note)")
        case "chef":
            appendActionLog("Chef reported: \(note)", "厨师结果：\(note)")
        case "spy":
            appendActionLog("\(actor.name) checked the Grimoire.", "\(actor.name) 查看了魔典。")
        case "alhadikhia":
            handleAlHadikhiaAction(actor: actor, targets: targets, note: note)
        case "pukka":
            if let previous = pukkaPoisonedPlayerId, let previousPlayer = playerLookup(by: previous), previousPlayer.alive {
                killByDemonIfAlive(previous, reason: ui("Pukka poison", "普卡毒杀"))
            }
            pukkaPoisonedPlayerId = targets.first
            appendActionLog("\(actor.name) poisoned \(targetText) as Pukka.", "\(actor.name) 以普卡之力毒了 \(targetText)。")
        case "shabaloth":
            for target in targets {
                resolveForcedDemonKill(target)
            }
            appendActionLog("\(actor.name) chose \(targetText) for the Shabaloth kill.", "\(actor.name) 选择 \(targetText) 作为沙巴洛斯夜杀目标。")
        case "legion":
            if let namedTarget = players.first(where: { $0.alive && note.lowercased().contains($0.name.lowercased()) }) {
                killByDemonIfAlive(namedTarget.id, reason: ui("Legion attack", "军团袭击"))
                appendActionLog("\(actor.name) resolved Legion on \(namedTarget.name).", "\(actor.name) 对 \(namedTarget.name) 结算了军团能力。")
            } else if let target = players.filter({ $0.alive && isPlayerGood($0) }).randomElement() {
                killByDemonIfAlive(target.id, reason: ui("Legion attack", "军团袭击"))
                appendActionLog("\(actor.name) resolved Legion on \(target.name).", "\(actor.name) 对 \(target.name) 结算了军团能力。")
            } else {
                appendActionLog("\(actor.name) had no Legion kill tonight.", "\(actor.name) 今夜没有军团击杀。")
            }
        case "lilmonsta":
            if let namedTarget = players.first(where: { $0.alive && note.lowercased().contains($0.name.lowercased()) }) {
                killByDemonIfAlive(namedTarget.id, reason: ui("Lil' Monsta attack", "小怪物袭击"))
                appendActionLog("\(actor.name) resolved Lil' Monsta on \(namedTarget.name).", "\(actor.name) 对 \(namedTarget.name) 结算了小怪物能力。")
            } else {
                appendActionLog("\(actor.name) recorded Lil' Monsta babysitting. \(note)", "\(actor.name) 记录了小怪物看护情况。\(note)")
            }
        case "po-demon":
            if let target = targets.first {
                resolveForcedDemonKill(target)
                poChargedPlayerIds.remove(actor.id)
                appendActionLog("\(actor.name) chose \(targetText) for the Po kill.", "\(actor.name) 选择 \(targetText) 作为波的夜杀目标。")
            } else {
                poChargedPlayerIds.insert(actor.id)
                appendActionLog("\(actor.name) did not kill tonight and charged the Po.", "\(actor.name) 今夜没有击杀，并蓄力了波。")
            }
        case "snake-charmer":
            if let target = targets.first,
               let targetIndex = players.firstIndex(where: { $0.id == target }),
               roleTemplate(for: players[targetIndex].roleId ?? "")?.team == .demon,
               let actorIndex = players.firstIndex(where: { $0.id == actor.id }) {
                let oldActorRole = players[actorIndex].roleId
                players[actorIndex].roleId = players[targetIndex].roleId
                players[targetIndex].roleId = oldActorRole
                alignmentOverrides[players[actorIndex].id] = true
                alignmentOverrides[players[targetIndex].id] = false
                appendActionLog("\(actor.name) swapped roles with \(players[targetIndex].name).", "\(actor.name) 与 \(players[targetIndex].name) 交换了角色。")
            }
        case "fang-gu":
            if let target = targets.first, let targetPlayer = playerLookup(by: target) {
                if roleTemplate(for: targetPlayer.roleId ?? "")?.team == .outsider,
                   !fangGuJumpUsedPlayerIds.contains(actor.id),
                   let targetIndex = players.firstIndex(where: { $0.id == target }) {
                    fangGuJumpUsedPlayerIds.insert(actor.id)
                    players[targetIndex].roleId = "fang-gu"
                    alignmentOverrides[target] = true
                    killIfAlive(actor.id, reason: ui("Fang Gu jump", "方固转移"))
                    appendActionLog("\(actor.name) jumped to \(targetPlayer.name) as Fang Gu.", "\(actor.name) 将方固转移给了 \(targetPlayer.name)。")
                } else {
                    resolveDemonKill(target)
                    appendActionLog("\(actor.name) chose a Fang Gu kill target: \(targetText).", "\(actor.name) 选择了方固夜杀目标：\(targetText)。")
                }
            }
        case "vigormortis":
            if let target = targets.first {
                if resolveDemonKill(target) {
                    applyVigormortisAfterKill(target)
                }
                appendActionLog("\(actor.name) chose a Vigormortis kill target: \(targetText).", "\(actor.name) 选择了维戈莫提斯夜杀目标：\(targetText)。")
            }
        case "no-dashii":
            if let target = targets.first {
                resolveDemonKill(target)
                appendActionLog("\(actor.name) chose a No Dashii kill target: \(targetText).", "\(actor.name) 选择了诺达希夜杀目标：\(targetText)。")
            }
        case "lordoftyphon":
            if let target = targets.first {
                resolveDemonKill(target)
                appendActionLog("\(actor.name) chose a Lord of Typhon kill target: \(targetText).", "\(actor.name) 选择了提丰之主夜杀目标：\(targetText)。")
            }
        case "ojo":
            handleOjoAction(actor: actor, note: note)
        case "yaggababble":
            handleYaggababbleAction(actor: actor, note: note)
        case "zombuul":
            if !didDeathOccurToday, let target = targets.first {
                resolveDemonKill(target)
                appendActionLog("\(actor.name) chose a Zombuul kill target: \(targetText).", "\(actor.name) 选择了僵怖夜杀目标：\(targetText)。")
            } else {
                appendActionLog("\(actor.name) had no Zombuul kill tonight.", "\(actor.name) 今夜没有僵怖击杀。")
            }
        case "pit-hag":
            if let target = targets.first,
               let transformedRoleId = parseRoleId(from: note),
               let targetIndex = players.firstIndex(where: { $0.id == target }),
               players[targetIndex].roleId != transformedRoleId,
               !players.contains(where: { $0.id != target && $0.roleId == transformedRoleId }) {
                let oldAlignment = isPlayerEvil(players[targetIndex])
                let oldRoleName = localizedRoleName(roleTemplate(for: players[targetIndex].roleId ?? ""))
                let newRoleName = localizedRoleName(roleTemplate(for: transformedRoleId))
                players[targetIndex].roleId = transformedRoleId
                alignmentOverrides[target] = oldAlignment
                appendActionLog("\(actor.name) transformed \(players[targetIndex].name) from \(oldRoleName) to \(newRoleName).", "\(actor.name) 将 \(players[targetIndex].name) 从 \(oldRoleName) 变为 \(newRoleName)。")
            } else {
                appendActionLog("\(actor.name) could not complete the Pit-Hag transformation.", "\(actor.name) 未能完成坑巫变形。")
            }
        case "evil-twin":
            if let goodTwinId = evilTwinGoodPlayerId,
               let goodTwin = playerLookup(by: goodTwinId) {
                appendActionLog("\(actor.name) remains linked to \(goodTwin.name).", "\(actor.name) 依旧与 \(goodTwin.name) 保持双子连接。")
            } else {
                appendActionLog("\(actor.name) had no twin pair configured.", "\(actor.name) 当前没有配置双子配对。")
            }
        case "engineer":
            handleEngineerChange(note: note, actor: actor)
        case "summoner":
            handleSummonerAction(actor: actor, targets: targets, note: note)
        case "wizard":
            if !wizardUsedPlayerIds.contains(actor.id) {
                wizardUsedPlayerIds.insert(actor.id)
                appendActionLog("\(actor.name) made a Wizard wish. \(note)", "\(actor.name) 许下了巫师愿望。\(note)")
            } else {
                appendActionLog("\(actor.name) has already used the Wizard ability.", "\(actor.name) 已经使用过巫师能力。")
            }
        case "xaan":
            appendActionLog("\(actor.name) marked Xaan night \(xaanNightNumber ?? 0).", "\(actor.name) 标记了夏安将在第 \(xaanNightNumber ?? 0) 夜生效。")
        case "scarletwoman":
            appendActionLog("\(actor.name) considered demon-shift effects. \(note)", "\(actor.name) 结算了恶魔转移相关效果。\(note)")
        case "dreamer":
            if let targetId = targets.first, let target = playerLookup(by: targetId) {
                let info = note.isEmpty ? ui("(no result recorded)", "（未记录结果）") : note
                appendActionLog("\(actor.name) chose \(target.name). Shown: \(info).", "\(actor.name) 选择了 \(target.name)。展示：\(info)。")
                markPlayer(actor.id) { player in
                    player.roleLog.append(ui("Chose \(target.name): \(info)", "选择 \(target.name)：\(info)"))
                }
            } else {
                appendActionLog("\(actor.name) did not choose a player.", "\(actor.name) 未选择玩家。")
            }
        case "mathematician":
            let number = note.isEmpty ? "0" : note
            appendActionLog("\(actor.name) learned the number: \(number).", "\(actor.name) 得知数字：\(number)。")
            markPlayer(actor.id) { player in
                player.roleLog.append(ui("Number learned: \(number)", "得知数字：\(number)"))
            }
        case "vortox":
            if let target = targets.first {
                resolveDemonKill(target)
                appendActionLog("\(actor.name) chose a Vortox kill target: \(targetText).", "\(actor.name) 选择了沃托克斯夜杀目标：\(targetText)。")
            }
        default:
            let roleName = localizedRoleName(roleTemplate(for: roleId))
            appendActionLog("\(roleName) action completed.", "\(roleName) 的行动已完成。")
        }

        appendRoleRecord(
            for: actor.id,
            text: currentLogLine(for: actor, roleId: roleId, targetText: recordTargetText, note: recordNote),
            toneOverride: currentActionLogToneOverride
        )
        appendNightActionRecord(actor: actor.id, roleId: roleId, targets: recordTargets, note: recordNote)
        currentActionLogToneOverride = nil
        if isAwaitingImpReplacementSelection {
            return
        }
        proceedToNextNightStep()
    }

    func skipCurrentNightStep() {
        skippedNightStepIndices.insert(currentNightStepIndex)
        proceedToNextNightStep()
    }

    func proceedToNextNightStep() {
        currentNightTargets.removeAll()
        currentNightNote = ""
        currentNightAlignmentSelections.removeAll()
        currentNightStepIndex += 1
        advanceToCurrentActiveNightStep()
    }

    func resolveNightDawn() {
        resolveGossipKillIfNeeded()
        resolveMoonchildKillIfNeeded()
        resolveXaanPoisoningIfNeeded()
        resolveAcrobatDeathsIfNeeded()
        resolveChoirboyInfoIfNeeded()
        resolveCultLeaderAlignmentAtDawn()

        if impDiedTonight {
            promoteMinionAfterImpDeath()
            if isGameOver {
                return
            }
        }

        deadTonight = Set(players.filter { $0.isDeadTonight }.map(\.id))
        demonKillBlockedTonight = false
        exorcisedPlayerId = nil
        gossipKillTonight = false
        princessProtectedNightAfterDay = nil

        clearNightAfterDawn()
        isFirstNightPhase = false
        phase = .day
        currentDayNumber += 1
        handleDayStartEffects()
        startTimer(seconds: dayPreset)
        clearDayState()
        gameOverCheck()
    }

    func clearNightAfterDawn() {
        for index in players.indices {
            if players[index].poisonedTonight {
                players[index].roleLog.removeAll {
                    $0.contains("Poisoned tonight") || $0.contains("今夜中毒")
                }
            }
            players[index].poisonedTonight = false
            players[index].protectedTonight = false
            players[index].wasButlerTonight = false
            players[index].becameDemonTonight = false
            players[index].isDeadTonight = false
        }
        demonProtectedTonight.removeAll()
        protectedTonight.removeAll()
        updateNoDashiiPoisoning()
    }

    func resolveGossipKillIfNeeded() {
        guard gossipKillTonight,
              let gossip = players.first(where: { $0.roleId == "gossip" && $0.alive && !isAbilitySuppressed($0) }) else {
            return
        }
        let candidates = players.filter { $0.alive && $0.id != gossip.id }
        guard let target = candidates.randomElement() else { return }
        killIfAlive(target.id, reason: ui("Gossip kill", "流言击杀"))
        addLog(
            "A true Gossip statement killed \(target.name) tonight.",
            "真实流言在今夜杀死了 \(target.name)。"
        )
    }

    func resolveMoonchildKillIfNeeded() {
        guard let moonchild = pendingMoonchild,
              let targetId = moonchildPendingTargetId,
              let target = playerLookup(by: targetId) else {
            return
        }
        defer {
            moonchildPendingPlayerId = nil
            moonchildPendingTargetId = nil
        }
        if isPlayerGood(target) {
            killIfAlive(target.id, reason: ui("Moonchild pick", "月之子选择"))
            addLog(
                "Moonchild \(moonchild.name) caused \(target.name) to die.",
                "月之子 \(moonchild.name) 让 \(target.name) 死亡。"
            )
        } else {
            addLog(
                "Moonchild \(moonchild.name) chose \(target.name), but they were evil and survived.",
                "月之子 \(moonchild.name) 选择了 \(target.name)，但其为邪恶玩家，因此存活。"
            )
        }
    }

    func resolveAcrobatDeathsIfNeeded() {
        for (acrobatId, trackedId) in acrobatTrackedPlayerIds {
            guard let acrobat = playerLookup(by: acrobatId),
                  acrobat.alive,
                  !isAbilitySuppressed(acrobat),
                  let tracked = playerLookup(by: trackedId) else {
                continue
            }
            if playerIsPoisonedOrDrunk(tracked) {
                killIfAlive(acrobat.id, reason: ui("Acrobat detected poison or drunkenness", "杂技演员发现醉酒或中毒"))
                addLog(
                    ui("Acrobat \(acrobat.name) died because \(tracked.name) was drunk or poisoned.", "杂技演员 \(acrobat.name) 因 \(tracked.name) 醉酒或中毒而死亡。")
                )
            }
        }
        acrobatTrackedPlayerIds.removeAll()
    }

    func resolveChoirboyInfoIfNeeded() {
        guard kingKilledByDemonPlayerId != nil,
              let choirboy = players.first(where: { $0.roleId == "choirboy" && $0.alive && !isAbilitySuppressed($0) }),
              let demon = players.first(where: { $0.alive && roleTemplate(for: $0.roleId ?? "")?.team == .demon }) else {
            return
        }
        markPlayer(choirboy.id) { player in
            player.roleLog.append(ui("Learned that \(demon.name) is the Demon.", "得知 \(demon.name) 是恶魔。"))
        }
        addLog(
            ui("Choirboy \(choirboy.name) learned that \(demon.name) is the Demon.", "唱诗班男孩 \(choirboy.name) 得知 \(demon.name) 是恶魔。")
        )
        kingKilledByDemonPlayerId = nil
    }

    func resolveCultLeaderAlignmentAtDawn() {
        guard let cultLeader = players.first(where: { $0.roleId == "cultleader" && $0.alive && !isAbilitySuppressed($0) }) else {
            return
        }
        let neighbors = aliveNeighbors(of: cultLeader)
        guard neighbors.count == 2 else { return }
        let leftIsEvil = isPlayerEvil(neighbors[0])
        let rightIsEvil = isPlayerEvil(neighbors[1])
        guard leftIsEvil == rightIsEvil else { return }
        let previous = isPlayerEvil(cultLeader)
        alignmentOverrides[cultLeader.id] = leftIsEvil
        if previous != leftIsEvil {
            addLog(
                ui("\(cultLeader.name) changed alignment as the Cult Leader.", "\(cultLeader.name) 作为邪教领袖改变了阵营。")
            )
        }
    }

    func resolveXaanPoisoningIfNeeded() {
        guard let xaanNightNumber,
              players.contains(where: { $0.alive && $0.roleId == "xaan" }) else {
            return
        }
        let nightNumber = isFirstNightPhase ? 1 : currentDayNumber + 1
        guard nightNumber == xaanNightNumber else { return }
        xaanPoisonedUntilDayNumber = currentDayNumber + 1
        addLog(
            ui("Xaan poisoned all Townsfolk until dusk.", "夏安使所有镇民中毒直到黄昏。")
        )
    }

    func applyVigormortisAfterKill(_ targetId: UUID) {
        guard let target = playerLookup(by: targetId),
              !target.alive,
              roleTemplate(for: target.roleId ?? "")?.team == .minion else {
            return
        }
        vigormortisEmpoweredMinionIds.insert(target.id)
        let seatedPlayers = players.sorted { $0.seatNumber < $1.seatNumber }
        guard let index = seatedPlayers.firstIndex(where: { $0.id == target.id }), !seatedPlayers.isEmpty else {
            return
        }
        let left = seatedPlayers[(index - 1 + seatedPlayers.count) % seatedPlayers.count]
        let right = seatedPlayers[(index + 1) % seatedPlayers.count]
        for neighbor in [left, right] {
            if neighbor.alive, let role = roleTemplate(for: neighbor.roleId ?? ""), role.team == .townsfolk {
                vigormortisPoisonedNeighborIds.insert(neighbor.id)
            }
        }
        addLog(
            "Vigormortis empowered dead Minion \(target.name), poisoning their Townsfolk neighbors.",
            "维戈莫提斯让死亡的爪牙 \(target.name) 保留能力，并毒化其相邻镇民。"
        )
    }

    func handleDayStartEffects() {
        if currentDayNumber == 1, players.contains(where: { $0.roleId == "leviathan" }) {
            addLog(
                ui("Leviathan is in play. Everyone knows this.", "利维坦在场。所有人都知道这一点。")
            )
        }

        if currentDayNumber >= 3,
           !riotActivated,
           players.contains(where: { $0.roleId == "riot" }) {
            riotActivated = true
            for index in players.indices where players[index].alive {
                guard let role = roleTemplate(for: players[index].roleId ?? "") else { continue }
                if role.team == .minion {
                    players[index].roleId = "riot"
                    players[index].roleLog.append(ui("Became Riot.", "转变为暴乱。"))
                }
            }
            addLog("Riot day has begun. Minions become Riot and nominees die immediately.", "暴乱日开始。所有爪牙转变为暴乱，被提名者会立即死亡。")
        }
    }

    func updateNoDashiiPoisoning() {
        noDashiiPoisonedPlayerIds.removeAll()
        guard let noDashii = players.first(where: { $0.alive && $0.roleId == "no-dashii" }) else { return }
        let sortedPlayers = players.sorted { $0.seatNumber < $1.seatNumber }
        guard let index = sortedPlayers.firstIndex(where: { $0.id == noDashii.id }), !sortedPlayers.isEmpty else { return }
        let left = sortedPlayers[(index - 1 + sortedPlayers.count) % sortedPlayers.count]
        let right = sortedPlayers[(index + 1) % sortedPlayers.count]
        for neighbor in [left, right] {
            if let role = roleTemplate(for: neighbor.roleId ?? ""), role.team == .townsfolk {
                noDashiiPoisonedPlayerIds.insert(neighbor.id)
            }
        }
    }

    func prepareImpReplacementSelection() {
        guard impDiedTonight else { return }
        let candidates = players.filter { player in
            player.alive && roleTemplate(for: player.roleId ?? "")?.team == .minion
        }
        .sorted { $0.seatNumber < $1.seatNumber }

        guard !candidates.isEmpty else { return }
        pendingImpReplacementCandidateIds = candidates.map(\.id)
        addLog(
            "Choose a living Minion to become the new Imp.",
            "请选择一名存活爪牙成为新的小恶魔。"
        )
    }

    func selectImpReplacement(_ playerId: UUID) {
        guard pendingImpReplacementCandidateIds.contains(playerId),
              let index = players.firstIndex(where: { $0.id == playerId }) else {
            return
        }

        let oldRole = localizedRoleName(roleTemplate(for: players[index].roleId ?? ""))
        players[index].roleId = "imp"
        players[index].becameDemonTonight = true
        players[index].roleLog.append(ui("Became the Demon.", "转变为恶魔。"))
        players[index].roleLog.append(ui("Replacement selected after the Imp died.", "在小恶魔死亡后被选为替代恶魔。"))

        addLog(
            "The Imp died and \(players[index].name) became the new Imp from \(oldRole).",
            "小恶魔死亡，\(players[index].name) 从 \(oldRole) 转变为新的小恶魔。"
        )

        pendingImpReplacementCandidateIds.removeAll()
        impDiedTonight = false
        currentActionLogToneOverride = nil
        proceedToNextNightStep()
    }

    func promoteMinionAfterImpDeath() {
        guard impDiedTonight else { return }
        var aliveMinions: [Int] = []
        for idx in players.indices {
            let player = players[idx]
            guard player.alive else { continue }
            guard roleTemplate(for: player.roleId ?? "")?.team == .minion else { continue }
            aliveMinions.append(idx)
        }

        guard !aliveMinions.isEmpty else {
            addLog("The Imp died, but no Minion was alive to become the new Demon.", "小恶魔死亡，但没有存活爪牙可以转变为新恶魔。")
            impDiedTonight = false
            gameOverCheck()
            return
        }

        // The Imp is already dead, so add 1 to get the alive count before death.
        // Per rules: "If there are 5 or more players alive [before death] & the Demon dies,
        // you [Scarlet Woman] become the Demon."
        let aliveCountBeforeDeath = players.filter(\.alive).count + 1
        let replacementIndex: Int?
        if aliveCountBeforeDeath >= 5,
           let scarletIndex = players.firstIndex(where: { $0.alive && $0.roleId == "scarletwoman" }) {
            replacementIndex = scarletIndex
        } else {
            replacementIndex = aliveMinions.randomElement()
        }

        guard let index = replacementIndex else {
            addLog("The Imp died, but no replacement candidate was available.", "小恶魔死亡，但没有可用的替代者。")
            impDiedTonight = false
            gameOverCheck()
            return
        }

        let oldRole = localizedRoleName(roleTemplate(for: players[index].roleId ?? ""))
        let wasScarlet = players[index].roleId == "scarletwoman"
        players[index].roleId = "imp"
        players[index].becameDemonTonight = true
        players[index].roleLog.append(ui("Became the Demon.", "转变为恶魔。"))
        players[index].roleLog.append(ui("Replacement selected after the Imp died.", "在小恶魔死亡后被选为替代恶魔。"))
        if wasScarlet {
            addLog("The Imp died and the Scarlet Woman became the new Imp.", "小恶魔死亡，红唇女郎转变为新的小恶魔。")
        } else {
            addLog("The Imp died and \(oldRole) became the new Imp.", "小恶魔死亡，\(oldRole) 转变为新的小恶魔。")
        }
        impDiedTonight = false
    }

    func prepareFirstNightExperimentalState() {
        if players.contains(where: { $0.roleId == "bountyhunter" }),
           bountyHunterEvilPlayerId == nil {
            assignBountyHunterEvilPlayer()
        }
        if players.contains(where: { $0.roleId == "evil-twin" }),
           evilTwinPlayerId == nil {
            assignEvilTwinPair()
        }
        if players.contains(where: { $0.roleId == "villageidiot" }) {
            assignVillageIdiotDrunkPlayer()
        }
        if players.contains(where: { $0.roleId == "xaan" }) {
            xaanNightNumber = max(1, deckTeamCounts().outsiders)
        }
    }
    func assignBountyHunterEvilPlayer() {
        let eligible = players.filter { player in
            guard player.alive,
                  player.roleId != "bountyhunter",
                  let role = roleTemplate(for: player.roleId ?? "") else { return false }
            return role.team == .townsfolk
        }

        guard let chosen = eligible.randomElement() else { return }
        bountyHunterEvilPlayerId = chosen.id
        alignmentOverrides[chosen.id] = true
        addLog(
            "Bounty Hunter setup: \(chosen.name) became evil.",
            "赏金猎人设定：\(chosen.name) 转为邪恶阵营。"
        )
    }

    func assignEvilTwinPair() {
        guard let evilTwin = players.first(where: { $0.roleId == "evil-twin" }) else { return }
        let eligible = players.filter { player in
            player.id != evilTwin.id && player.alive && isPlayerGood(player)
        }
        guard let goodTwin = eligible.randomElement() else { return }
        evilTwinPlayerId = evilTwin.id
        evilTwinGoodPlayerId = goodTwin.id
        markPlayer(evilTwin.id) { player in
            player.roleLog.append(ui("Your good twin is \(goodTwin.name).", "你的善良双子是 \(goodTwin.name)。"))
        }
        markPlayer(goodTwin.id) { player in
            player.roleLog.append(ui("Your evil twin is \(evilTwin.name).", "你的邪恶双子是 \(evilTwin.name)。"))
        }
        addLog(
            "Evil Twin setup linked \(evilTwin.name) and \(goodTwin.name).",
            "邪恶双子设定将 \(evilTwin.name) 与 \(goodTwin.name) 连接为双子。"
        )
    }
    func shouldWakeBountyHunterTonight() -> Bool {
        guard let knownId = bountyHunterKnownPlayerId else { return true }
        return players.contains(where: { $0.id == knownId && !$0.alive })
    }

    func bountyHunterRevealPlayer() -> PlayerCard? {
        let evilPlayers = players.filter { isPlayerEvil($0) }
        let preferred = evilPlayers.filter { !bountyHunterKnownHistory.contains($0.id) }
        let pool = preferred.isEmpty ? evilPlayers : preferred
        guard let chosen = pool.randomElement() else { return nil }
        bountyHunterKnownPlayerId = chosen.id
        bountyHunterKnownHistory.insert(chosen.id)
        return chosen
    }

    func balloonistRevealPlayer(suppressed: Bool) -> PlayerCard? {
        let candidates = players.filter { $0.alive }
        guard !candidates.isEmpty else { return nil }
        let pool: [PlayerCard]
        if suppressed || balloonistLastShownType == nil {
            pool = candidates
        } else {
            pool = candidates.filter {
                guard let role = roleTemplate(for: $0.roleId ?? "") else { return false }
                return role.team != balloonistLastShownType
            }
        }
        guard let chosen = (pool.isEmpty ? candidates : pool).randomElement(),
              let chosenRole = roleTemplate(for: chosen.roleId ?? "") else { return nil }
        balloonistLastShownType = chosenRole.team
        return chosen
    }
    func generalAlignmentResult() -> (english: String, chinese: String) {
        let alivePlayers = players.filter(\.alive)
        let aliveGoodCount = alivePlayers.filter { isPlayerGood($0) }.count
        let aliveEvilCount = alivePlayers.filter { isPlayerEvil($0) }.count

        if alivePlayers.contains(where: { roleTemplate(for: $0.roleId ?? "")?.team == .demon }) == false {
            return ("good is winning", "善良阵营占优")
        }
        if aliveEvilCount >= aliveGoodCount {
            return ("evil is winning", "邪恶阵营占优")
        }
        if !evilHasPossibleWinningPath(alivePlayers: alivePlayers) {
            return ("good is winning", "善良阵营占优")
        }
        if aliveGoodCount - aliveEvilCount >= 2 {
            return ("good is winning", "善良阵营占优")
        }
        return ("neither team is clearly winning", "目前双方都没有明显优势")
    }

    func assignVillageIdiotDrunkPlayer() {
        let villageIdiots = players.filter { $0.roleId == "villageidiot" }
        guard villageIdiots.count > 1 else {
            villageIdiotDrunkPlayerId = nil
            return
        }
        villageIdiotDrunkPlayerId = villageIdiots.randomElement()?.id
    }

    func villageIdiotResult(for target: PlayerCard) -> (english: String, chinese: String) {
        let actualIsEvil = detectedIsEvil(target)
        let isDrunkVillageIdiot = currentNightActor?.id == villageIdiotDrunkPlayerId
        let shownIsEvil = isDrunkVillageIdiot ? !actualIsEvil : actualIsEvil
        return shownIsEvil ? ("evil", "邪恶") : ("good", "善良")
    }

    var nightStepReminder: String {
        guard let step = currentNightStep, let actor = currentNightActor, let role = roleTemplate(for: step.roleId) else {
            return isFirstNightPhase
                ? ui("First night is complete. Wait for dawn.", "第一夜流程结束，等待天亮。")
                : ui("Night is complete. Wait for dawn.", "夜晚流程结束，等待天亮。")
        }
        let abilityText = localizedRoleSummary(role)
        let base = ui(
            "Wake: \(actor.name) as \(role.name)\n\(abilityText)",
            "本夜请唤起：\(actor.name) 的 \(role.chineseName)\n\(abilityText)"
        )
        if let guidance = currentNightDrunkGuidance(roleId: step.roleId) {
            return "\(base)\n\n\(guidance)"
        }
        if let guidance = currentNightSuppressionGuidance(roleId: step.roleId) {
            return "\(base)\n\n\(guidance)"
        }
        return base
    }
}

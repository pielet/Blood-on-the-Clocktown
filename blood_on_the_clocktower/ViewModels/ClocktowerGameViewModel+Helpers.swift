import Foundation
import SwiftUI

extension ClocktowerGameViewModel {

    // MARK: - Role/Player Identification Helpers

    func playerActsAsRole(_ player: PlayerCard, roleId: String) -> Bool {
        player.roleId == roleId || (player.roleId == "drunk" && player.displayedRoleId == roleId)
    }

    func isDisplayedDrunk(_ player: PlayerCard, actingAs roleId: String) -> Bool {
        player.roleId == "drunk" && player.displayedRoleId == roleId
    }

    func apparentRoleId(for player: PlayerCard) -> String? {
        if let displayedRoleId = player.displayedRoleId, player.roleId == "drunk" {
            return displayedRoleId
        }
        return player.roleId
    }

    func apparentRoleName(for player: PlayerCard, fallbackRoleId: String? = nil) -> String {
        let roleId = fallbackRoleId ?? apparentRoleId(for: player)
        return localizedRoleName(roleId.flatMap { roleTemplate(for: $0) })
    }

    func actingPlayer(
        for roleId: String,
        requireAlive: Bool = false,
        requireCanWake: Bool = false,
        requireUnsuppressed: Bool = false
    ) -> PlayerCard? {
        let candidates = players.filter { player in
            guard playerActsAsRole(player, roleId: roleId) else { return false }
            if requireAlive && !player.alive { return false }
            if requireCanWake && !canWakeAtNight(player) { return false }
            if requireUnsuppressed && isAbilitySuppressed(player) && !isDisplayedDrunk(player, actingAs: roleId) {
                return false
            }
            return true
        }

        return candidates.sorted { lhs, rhs in
            if lhs.roleId == roleId && rhs.roleId != roleId { return true }
            if rhs.roleId == roleId && lhs.roleId != roleId { return false }
            return lhs.seatNumber < rhs.seatNumber
        }.first
    }

    func isCurrentNightDisplayedDrunk(for roleId: String? = nil) -> Bool {
        guard let actor = currentNightActor else { return false }
        let expectedRoleId = roleId ?? currentNightStep?.roleId
        guard let expectedRoleId else { return false }
        return isDisplayedDrunk(actor, actingAs: expectedRoleId)
    }

    func currentNightDrunkGuidance(roleId: String) -> String? {
        guard let actor = currentNightActor, isDisplayedDrunk(actor, actingAs: roleId) else { return nil }
        let role = roleTemplate(for: roleId)
        let engName = role?.name ?? roleId
        let chnName = role?.chineseName ?? roleId
        return ui(
            "\(actor.name) is actually the Drunk. Wake them as \(engName), but give false information and apply no real effect.",
            "\(actor.name) 的真实身份是酒鬼。请按 \(chnName) 唤醒，但给出错误信息，且不要产生真实效果。"
        )
    }

    // MARK: - Night Suppression / Drunk Handling

    func currentNightSuppressionGuidance(roleId: String) -> String? {
        guard let actor = currentNightActor,
              !isDisplayedDrunk(actor, actingAs: roleId),
              isPlayerExternallyPoisonedOrDrunk(actor) else {
            return nil
        }

        let role = roleTemplate(for: roleId)
        let engName = role?.name ?? roleId
        let chnName = role?.chineseName ?? roleId
        if playerIsPoisoned(actor) {
            return ui(
                "\(actor.name) is poisoned. Give false info, or no real effect.",
                "\(actor.name) 已中毒。给出错误信息；若无信息能力，则不产生真实效果。"
            )
        }

        return ui(
            "\(actor.name) is drunk. Wake them and let them use \(engName), but give false information. If the ability has no information, accept the choice but apply no real effect.",
            "\(actor.name) 当前醉酒。请照常按 \(chnName) 唤醒并让其使用能力，但要给出错误信息；若该能力没有信息，则照常记录选择，但不要产生真实效果。"
        )
    }

    enum NightReminderHighlightStyle: Equatable {
        case poison
        case drunk
    }

    func currentNightReminderHighlightStyle(for roleId: String) -> NightReminderHighlightStyle? {
        guard let actor = currentNightActor else { return nil }
        if playerIsPoisoned(actor) {
            return .poison
        }
        if isDisplayedDrunk(actor, actingAs: roleId) || isPlayerExternallyPoisonedOrDrunk(actor) {
            return .drunk
        }
        return nil
    }

    func actingDayPlayer(for roleId: String, requireUnsuppressed: Bool = true) -> PlayerCard? {
        actingPlayer(for: roleId, requireAlive: true, requireUnsuppressed: requireUnsuppressed)
    }

    // MARK: - Displayed Drunk Actions

    func markDisplayedDrunkNightUsage(actor: PlayerCard, roleId: String) {
        switch roleId {
        case "nightwatchman":
            nightwatchmanUsedPlayerIds.insert(actor.id)
        case "professor":
            professorUsedPlayerIds.insert(actor.id)
        case "courtier":
            courtierUsedPlayerIds.insert(actor.id)
        case "huntsman":
            huntsmanUsedPlayerIds.insert(actor.id)
        case "seamstress":
            seamstressUsedPlayerIds.insert(actor.id)
        case "engineer":
            engineerUsedPlayerIds.insert(actor.id)
        case "juggler":
            jugglerResolvedPlayerIds.insert(actor.id)
        default:
            break
        }
    }

    func handleDisplayedDrunkTroubleBrewingFirstNightInfo(
        actor: PlayerCard,
        roleId: String,
        targets: [UUID],
        note: String
    ) {
        let chosenNames = targets.compactMap { playerLookup(by: $0)?.name }.joined(separator: ", ")
        let shownRoleId = decodedNightRoleChoice(from: note).roleId
        let registrationSuffix = troubleBrewingRegistrationLogSuffix(from: note)
        let message = TroubleBrewingInfoSupport.displayedDrunkInformationalMessage(
            roleId: roleId,
            context: TroubleBrewingInfoSupport.Context(
                actorName: actor.name,
                chosenNames: chosenNames,
                shownRoleName: shownRoleId.flatMap { roleTemplate(for: $0) }.map(localizedRoleName),
                registrationSuffix: .init(
                    english: registrationSuffix.english,
                    chinese: registrationSuffix.chinese
                ),
                isNoOutsiderResult: note == noOutsiderChoiceID
            ),
        )
        appendActionLog(message.english, message.chinese)
    }

    func handleDisplayedDrunkNightAction(
        actor: PlayerCard,
        roleId: String,
        targets: [UUID],
        targetText: String,
        note: String
    ) {
        currentActionLogToneOverride = .drunk
        markDisplayedDrunkNightUsage(actor: actor, roleId: roleId)

        let role = roleTemplate(for: roleId)
        let engRoleName = role?.name ?? roleId
        let chnRoleName = role?.chineseName ?? roleId
        let isInfoRole = role?.needsNightResultInput == true || roleId == "undertaker"

        switch roleId {
        case "washerwoman", "librarian", "investigator":
            handleDisplayedDrunkTroubleBrewingFirstNightInfo(actor: actor, roleId: roleId, targets: targets, note: note)
        case "nightwatchman":
            if let targetId = targets.first,
               let targetPlayer = playerLookup(by: targetId) {
                appendActionLog("\(actor.name) is actually the Drunk. \(targetPlayer.name) was falsely treated as confirmed by the Nightwatchman.", "\(actor.name) 的真实身份是酒鬼。说书人将 \(targetPlayer.name) 错误地当作收到了守夜人确认。")
            } else {
                appendActionLog("\(actor.name) is actually the Drunk. They woke as Nightwatchman, but no real confirmation happened.", "\(actor.name) 的真实身份是酒鬼。其以守夜人身份醒来，但没有发生真实确认。")
            }
        case "professor":
            if let targetId = targets.first,
               let targetPlayer = playerLookup(by: targetId) {
                appendActionLog("\(actor.name) is actually the Drunk. They believed they revived \(targetPlayer.name), but nothing happened.", "\(actor.name) 的真实身份是酒鬼。其以为自己复活了 \(targetPlayer.name)，但没有真实效果。")
            } else {
                appendActionLog("\(actor.name) is actually the Drunk. They woke as Professor, but no real resurrection happened.", "\(actor.name) 的真实身份是酒鬼。其以教授身份醒来，但没有发生真实复活。")
            }
        default:
            if !targetText.isEmpty && !note.isEmpty {
                if isInfoRole {
                    appendActionLog("\(actor.name) is actually the Drunk. They chose \(targetText) as \(engRoleName) and were shown: \(note).", "\(actor.name) 的真实身份是酒鬼。其以 \(chnRoleName) 身份选择了 \(targetText)，并被错误告知：\(note)。")
                } else {
                    appendActionLog("\(actor.name) is actually the Drunk. They chose \(targetText) as \(engRoleName), but the action had no real effect. Recorded: \(note).", "\(actor.name) 的真实身份是酒鬼。其以 \(chnRoleName) 身份选择了 \(targetText)，但没有真实效果。记录：\(note)。")
                }
            } else if !targetText.isEmpty {
                appendActionLog("\(actor.name) is actually the Drunk. They chose \(targetText) as \(engRoleName), but the action had no real effect.", "\(actor.name) 的真实身份是酒鬼。其以 \(chnRoleName) 身份选择了 \(targetText)，但没有真实效果。")
            } else if !note.isEmpty {
                if isInfoRole {
                    appendActionLog("\(actor.name) is actually the Drunk and received false \(engRoleName) info: \(note).", "\(actor.name) 的真实身份是酒鬼，并收到了错误的 \(chnRoleName) 信息：\(note)。")
                } else {
                    appendActionLog("\(actor.name) is actually the Drunk. They acted as \(engRoleName), but the action had no real effect. Recorded: \(note).", "\(actor.name) 的真实身份是酒鬼。其以 \(chnRoleName) 身份行动，但没有真实效果。记录：\(note)。")
                }
            } else {
                appendActionLog("\(actor.name) is actually the Drunk. Wake them as \(engRoleName), but apply no real effect.", "\(actor.name) 的真实身份是酒鬼。请按 \(chnRoleName) 唤醒，但不要产生真实效果。")
            }
        }
    }

    func preferredNamedTargetId(from note: String, actor: PlayerCard, availableTargetIds: [UUID]) -> UUID? {
        let lowered = note.lowercased()
        if lowered.contains("self") || lowered.contains("myself") || note.contains(actor.name) {
            return actor.id
        }
        for targetId in availableTargetIds {
            if let name = playerName(targetId), lowered.contains(name.lowercased()) {
                return targetId
            }
        }
        return nil
    }

    // MARK: - Night/Day State Clearing + Record Helpers

    func clearNightState() {
        demonProtectedTonight.removeAll()
        protectedTonight.removeAll()
        deadTonight.removeAll()
        demonKilledTonight.removeAll()
        impDiedTonight = false
        demonKillBlockedTonight = false
        currentNightStepIndex = 0
        currentNightTargets.removeAll()
        currentNightNote = ""
        currentNightAlignmentSelections.removeAll()
        exorcisedPlayerId = nil
        selectedDeckCardId = nil
        selectedAssignmentPlayerId = nil
        pendingImpReplacementCandidateIds.removeAll()
        slayerSelectedTarget = nil
        nominatorID = nil
        goblinClaimedPlayerId = nil
        isGrimoireShowingBacks = true
        clearGrimoireReveals()
    }

    func clearDayState() {
        nomineeID = nil
        nominatorID = nil
        votesByVoter.removeAll()
        nominationResults.removeAll()
        goblinClaimedPlayerId = nil
        hasExecutionToday = false
        executedPlayerToday = nil
        outsiderExecutedToday = false
        demonVotedTodayFlag = false
        minionNominatedTodayFlag = false
        didDeathOccurToday = false
        nominationNominatorByNominee.removeAll()
        bansheeNominationsUsedByDay.removeAll()
        for index in players.indices {
            players[index].voteModifier = bansheeEmpoweredPlayerIds.contains(players[index].id) ? 2 : 0
        }
    }

    func appendRoleRecord(for playerID: UUID, text: String, toneOverride: LogTone? = nil) {
        let encodedText = encodedRecordedLog(text, toneOverride: toneOverride)
        markPlayer(playerID) { $0.roleLog.append(encodedText) }
    }

    // MARK: - Action Logging and Role Action Key

    func appendActionLog(_ text: String) {
        addLog(text, toneOverride: currentActionLogToneOverride)
    }

    func appendActionLog(_ english: String, _ chinese: String) {
        addLog(english, chinese, toneOverride: currentActionLogToneOverride)
    }

    func appendNightActionRecord(actor: UUID, roleId: String, targets: [UUID], note: String) {
        nightActionRecords.append(NightActionRecord(roleId: roleId, actorPlayerId: actor, selectedTargets: targets, note: note))
    }

    func handleTroubleBrewingFirstNightInfo(actor: PlayerCard, roleId: String, targets: [UUID], note: String) {
        let chosenPlayers = targets.compactMap { playerLookup(by: $0) }
        let chosenNames = chosenPlayers.map(\.name).joined(separator: ", ")
        let shownRoleId = decodedNightRoleChoice(from: note).roleId
        let registrationSuffix = troubleBrewingRegistrationLogSuffix(from: note)
        let message = TroubleBrewingInfoSupport.informationalMessage(
            roleId: roleId,
            context: TroubleBrewingInfoSupport.Context(
                actorName: actor.name,
                chosenNames: chosenNames,
                shownRoleName: shownRoleId.flatMap { roleTemplate(for: $0) }.map(localizedRoleName),
                registrationSuffix: .init(
                    english: registrationSuffix.english,
                    chinese: registrationSuffix.chinese
                ),
                isNoOutsiderResult: note == noOutsiderChoiceID
            ),
        )
        appendActionLog(message.english, message.chinese)
    }

    func currentLogLine(for actor: PlayerCard, roleId: String, targetText: String, note: String) -> String {
        let actionKey = roleActionKey(for: actor, roleId: roleId, targetText: targetText, note: note)
        let safeTargetText = targetText.replacingOccurrences(of: "|", with: "/")
        let safeNote = note.replacingOccurrences(of: "|", with: "/")
        return "\(roleActionRecordPrefix)\(actionKey)|\(actor.name)|\(safeTargetText)|\(safeNote)"
    }

    func roleActionKey(for actor: PlayerCard, roleId: String, targetText: String, note: String) -> String {
        switch roleId {
        case "acrobat":
            return "acrobat-track"
        case "alchemist":
            return "alchemist-grant"
        case "steward":
            return "steward-info"
        case "noble":
            return "noble-info"
        case "knight":
            return "knight-info"
        case "shugenja":
            return "shugenja-info"
        case "pixie":
            return "pixie-info"
        case "highpriestess":
            return "high-priestess-info"
        case "king":
            return "king-info"
        case "choirboy":
            return "choirboy-info"
        case "boffin":
            return "boffin-grant"
        case "grandmother":
            return "grandmother-link"
        case "sailor":
            return "sailor-drink"
        case "chambermaid":
            return "chambermaid-check"
        case "exorcist":
            return "exorcist-target"
        case "innkeeper":
            return "innkeeper-protect"
        case "gambler":
            return "gambler-guess"
        case "courtier":
            return "courtier-drunk"
        case "professor":
            return "professor-revive"
        case "devils-advocate":
            return "devils-advocate-protect"
        case "cultleader":
            return "cultleader-align"
        case "huntsman":
            return "huntsman-check"
        case "witch":
            return "witch-curse"
        case "assassin":
            return "assassin-attack"
        case "fearmonger":
            return "fearmonger-target"
        case "godfather":
            return targetText.isEmpty ? "godfather-none" : "godfather-kill"
        case "nightwatchman":
            return "nightwatchman-confirm"
        case "lunatic":
            return "lunatic-fake-kill"
        case "bountyhunter":
            return "bountyhunter-info"
        case "balloonist":
            return "balloonist-info"
        case "general":
            return "general-info"
        case "mezepheles":
            return "mezepheles-word"
        case "organgrinder":
            return "organgrinder-secret"
        case "villageidiot":
            return "villageidiot-check"
        case "poisoner":
            return "poisoner-poison"
        case "widow":
            return "widow-poison"
        case "monk":
            return "monk-protect"
        case "butler":
            return "butler-master"
        case "imp":
            return targetText == actor.name ? "imp-suicide" : "imp-kill"
        case "lleech":
            return isFirstNightPhase ? "lleech-host" : "lleech-kill"
        case "lycanthrope":
            return "lycanthrope-attack"
        case "preacher":
            return "preacher-choose"
        case "ravenkeeper":
            return "ravenkeeper-check"
        case "undertaker":
            return "undertaker-info"
        case "oracle":
            return "oracle-info"
        case "flowergirl":
            return "flowergirl-info"
        case "town-crier":
            return "town-crier-info"
        case "seamstress":
            return "seamstress-check"
        case "juggler":
            return "juggler-info"
        case "fortuneteller":
            return "fortuneteller-check"
        case "empath":
            return "empath-info"
        case "chef":
            return "chef-info"
        case "washerwoman":
            return "washerwoman-info"
        case "librarian":
            return "librarian-info"
        case "investigator":
            return "investigator-info"
        case "recluse":
            return "first-night-info"
        case "spy":
            return "spy-grimoire"
        case "pukka":
            return "pukka-poison"
        case "alhadikhia":
            return "alhadikhia-choice"
        case "shabaloth":
            return "shabaloth-kill"
        case "legion":
            return "legion-kill"
        case "lilmonsta":
            return "lilmonsta-night"
        case "po-demon":
            return targetText.isEmpty ? "po-charge" : "po-kill"
        case "snake-charmer":
            return "snake-charmer-check"
        case "fang-gu":
            return note.contains("jump") ? "fang-gu-jump" : "fang-gu-kill"
        case "vigormortis":
            return "vigormortis-kill"
        case "no-dashii":
            return "no-dashii-kill"
        case "lordoftyphon":
            return "lordoftyphon-kill"
        case "ojo":
            return "ojo-guess"
        case "yaggababble":
            return "yaggababble-phrase"
        case "zombuul":
            return targetText.isEmpty ? "zombuul-none" : "zombuul-kill"
        case "pit-hag":
            return "pit-hag-transform"
        case "evil-twin":
            return "evil-twin-link"
        case "engineer":
            return "engineer-change"
        case "summoner":
            return "summoner-create"
        case "wizard":
            return "wizard-wish"
        case "xaan":
            return "xaan-night"
        case "scarletwoman":
            return "scarletwoman-check"
        case "dreamer":
            return "dreamer-info"
        case "mathematician":
            return "mathematician-info"
        case "vortox":
            return "vortox-kill"
        default:
            return "generic"
        }
    }

    // MARK: - Core Player Utilities

    func markPlayer(_ playerID: UUID, _ updater: (inout PlayerCard) -> Void) {
        guard let index = players.firstIndex(where: { $0.id == playerID }) else { return }
        updater(&players[index])
    }

    func playerLookup(by id: UUID) -> PlayerCard? {
        players.first(where: { $0.id == id })
    }

    func playerName(_ playerId: UUID) -> String? {
        players.first(where: { $0.id == playerId })?.name
    }

    func orderedSeatedPlayers() -> [PlayerCard] {
        players.sorted { $0.seatNumber < $1.seatNumber }
    }

    func aliveNeighbors(of player: PlayerCard) -> [PlayerCard] {
        let living = orderedSeatedPlayers().filter(\.alive)
        guard living.count >= 2,
              let index = living.firstIndex(where: { $0.id == player.id }) else {
            return []
        }
        let left = living[(index - 1 + living.count) % living.count]
        let right = living[(index + 1) % living.count]
        return [left, right]
    }

    func parseRoleId(from note: String) -> String? {
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let normalized = trimmed.lowercased()
        return phaseTemplate.roles.first {
            $0.id.lowercased() == normalized ||
            $0.name.lowercased() == normalized ||
            $0.chineseName == trimmed
        }?.id
    }

    // MARK: - Alignment Checks

    func isPlayerEvil(_ player: PlayerCard) -> Bool {
        if let override = alignmentOverrides[player.id] {
            return override
        }
        if bountyHunterEvilPlayerId == player.id {
            return true
        }
        guard let role = roleTemplate(for: player.roleId ?? "") else { return false }
        return role.team == .minion || role.team == .demon
    }

    func isPlayerGood(_ player: PlayerCard) -> Bool {
        !isPlayerEvil(player)
    }

    // MARK: - Log Helpers

    func addLog(_ text: String, toneOverride: LogTone? = nil) {
        gameLog.insert(
            GameEvent(timestamp: Date(), phase: phase.rawValue, englishText: text, chineseText: text, toneOverride: toneOverride),
            at: 0
        )
    }

    func addLog(_ english: String, _ chinese: String, toneOverride: LogTone? = nil) {
        gameLog.insert(
            GameEvent(timestamp: Date(), phase: phase.rawValue, englishText: english, chineseText: chinese, toneOverride: toneOverride),
            at: 0
        )
    }
}

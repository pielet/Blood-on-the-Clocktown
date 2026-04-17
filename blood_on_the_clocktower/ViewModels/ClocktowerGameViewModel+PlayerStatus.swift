import Foundation
import SwiftUI

extension ClocktowerGameViewModel {

    // MARK: - Player Status

    func playerStatusItems(for player: PlayerCard) -> [String] {
        var items: [String] = []
        appendUniqueStatus(&items, player.alive ? ui("Alive", "存活") : ui("Dead", "死亡"))

        if let reason = player.deadReason, !player.alive {
            appendUniqueStatus(&items, "\(ui("Reason", "原因")): \(localizedRecordedReason(reason))")
        }
        if let displayedRoleId = player.displayedRoleId,
           displayedRoleId != player.roleId,
           let shownRole = roleTemplate(for: displayedRoleId) {
            appendUniqueStatus(&items, ui("Shown as \(localizedRoleName(shownRole))", "对玩家展示为 \(localizedRoleName(shownRole))"))
        }
        appendUniqueStatus(&items, persistentPoisonStatus(for: player))
        appendUniqueStatus(&items, persistentDrunkStatus(for: player))
        if bansheeEmpoweredPlayerIds.contains(player.id) {
            appendUniqueStatus(&items, ui("Banshee empowered", "女妖已强化"))
        }
        if fearmongerTargetByPlayerId.values.contains(player.id) {
            appendUniqueStatus(&items, ui("Fearmonger target", "恐惧贩子目标"))
        }
        if harpyMadPlayerId == player.id, let accusedId = harpyAccusedPlayerId {
            appendUniqueStatus(&items, ui("Harpy madness about \(playerName(accusedId) ?? "another player")", "鹰身女妖疯狂：必须指责 \(playerName(accusedId) ?? "另一名玩家")"))
        }
        if let pixieRoleId = pixieLearnedRoleByPlayerId[player.id] {
            appendUniqueStatus(&items, ui("Pixie learned \(localizedRoleName(roleTemplate(for: pixieRoleId)))", "小精灵得知：\(localizedRoleName(roleTemplate(for: pixieRoleId)))"))
        }
        if isSuppressedByPreacher(player) {
            appendUniqueStatus(&items, ui("Ability suppressed by Preacher", "能力被传教士压制"))
        }
        if player.protectedTonight {
            appendUniqueStatus(&items, ui("Protected tonight", "今夜受保护"))
        }
        if player.becameDemonTonight {
            appendUniqueStatus(&items, ui("Became the Demon tonight", "今夜转为恶魔"))
        }
        if player.wasButlerTonight {
            appendUniqueStatus(&items, ui("Linked by Butler tonight", "今夜是管家主从关系的一部分"))
        }
        if player.wasNominated {
            appendUniqueStatus(&items, ui("Nominated today", "今日被提名"))
        }
        if player.isDeadTonight {
            appendUniqueStatus(&items, ui("Died tonight", "今夜死亡"))
        }
        if player.slayerShotUsed {
            appendUniqueStatus(&items, ui("Slayer ability spent", "已使用猎手能力"))
        }
        if !player.alive {
            appendUniqueStatus(&items, player.ghostVoteAvailable ? ui("Dead vote available", "幽灵票可用") : ui("Dead vote spent", "幽灵票已用尽"))
        }

        return items
    }

    func appendUniqueStatus(_ items: inout [String], _ value: String?) {
        guard let value, !items.contains(value) else { return }
        items.append(value)
    }

    // MARK: - Persistent Poison Status

    func persistentPoisonStatus(for player: PlayerCard) -> String? {
        if poisonerPoisonIsActive(on: player) {
            return ui("Poisoned by Poisoner (until dusk)", "被投毒者投毒（持续至黄昏）")
        }
        if let widowPoisonedPlayerId, widowPoisonedPlayerId == player.id,
           players.contains(where: { $0.alive && $0.roleId == "widow" }) {
            return ui("Poisoned by Widow", "被寡妇投毒")
        }
        if let lleechHostPlayerId, lleechHostPlayerId == player.id,
           players.contains(where: { $0.alive && $0.roleId == "lleech" }) {
            return ui("Poisoned as Lleech host", "作为利奇宿主而中毒")
        }
        if let pukkaPoisonedPlayerId, pukkaPoisonedPlayerId == player.id,
           players.contains(where: { $0.alive && $0.roleId == "pukka" }) {
            return ui("Poisoned by Pukka", "被普卡投毒")
        }
        if noDashiiPoisonedPlayerIds.contains(player.id),
           players.contains(where: { $0.alive && $0.roleId == "no-dashii" }) {
            return ui("Poisoned by No Dashii", "被诺达希投毒")
        }
        if vigormortisPoisonedNeighborIds.contains(player.id),
           players.contains(where: { $0.alive && $0.roleId == "vigormortis" }) {
            return ui("Poisoned by Vigormortis", "被维戈莫提斯投毒")
        }
        if let xaanPoisonedUntilDayNumber,
           currentDayNumber <= xaanPoisonedUntilDayNumber,
           roleTemplate(for: player.roleId ?? "")?.team == .townsfolk,
           players.contains(where: { $0.alive && $0.roleId == "xaan" }) {
            return ui("Poisoned by Xaan", "被夏安投毒")
        }
        return nil
    }

    // MARK: - Persistent Drunk Status

    func persistentDrunkStatus(for player: PlayerCard) -> String? {
        if player.roleId == "drunk" {
            return ui("Drunk", "酒鬼")
        }
        if let sweetheartDrunkPlayerId, sweetheartDrunkPlayerId == player.id {
            return ui("Drunk from Sweetheart", "因甜心而醉酒")
        }
        if let untilDayNumber = temporaryDrunkPlayerUntilDayNumbers[player.id],
           untilDayNumber >= currentDayNumber {
            let source = temporaryDrunkPlayerSources[player.id] ?? "manual"
            switch source {
            case "sailor":
                return ui("Drunk from Sailor until dusk", "因水手而醉酒至黄昏")
            case "innkeeper":
                return ui("Drunk from Innkeeper until dusk", "因店主而醉酒至黄昏")
            default:
                return ui("Drunk until dusk", "醉酒至黄昏")
            }
        }
        if let roleId = player.roleId,
           let untilDayNumber = temporaryDrunkRoleUntilDayNumbers[roleId],
           untilDayNumber >= currentDayNumber {
            let source = temporaryDrunkRoleSources[roleId] ?? "manual"
            switch source {
            case "courtier":
                return ui("Drunk by Courtier", "被朝臣致醉")
            default:
                return ui("Drunk until dusk", "醉酒至黄昏")
            }
        }
        if let minstrelDrunkUntilDayNumber,
           currentDayNumber <= minstrelDrunkUntilDayNumber,
           player.roleId != "minstrel",
           isPlayerGood(player) {
            return ui("Drunk until dusk from Minstrel", "因吟游诗人而醉酒至黄昏")
        }
        if villageIdiotDrunkPlayerId == player.id {
            return ui("Drunk Village Idiot", "醉酒的村中傻子")
        }
        return nil
    }

    // MARK: - Preacher Suppression

    func isSuppressedByPreacher(_ player: PlayerCard) -> Bool {
        preachedMinionIds.contains(player.id) &&
        players.contains(where: { $0.alive && $0.roleId == "preacher" && !playerIsPoisonedOrDrunk($0) })
    }
}

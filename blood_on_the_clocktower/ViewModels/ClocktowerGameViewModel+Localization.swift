import Foundation
import SwiftUI

extension ClocktowerGameViewModel {

    // MARK: - Localization & Display

    var gameOverMessagePair: (english: String, chinese: String)? {
        guard let gameOverReason else { return nil }
        switch gameOverReason {
        case .mayorSurvived:
            return (
                "Good wins: the Mayor survived with 3 players left and no execution.",
                "善良阵营获胜：剩余 3 人且没有处决，镇长存活。"
            )
        case .saintExecuted:
            return (
                "Demon wins: the Saint was executed.",
                "恶魔阵营获胜：圣徒被处决。"
            )
        case .noDemonsAlive:
            return (
                "Good wins: no Demon is alive.",
                "善良阵营获胜：场上已没有存活恶魔。"
            )
        case .evilPopulationLead:
            return (
                "Demon wins: evil has reached parity with good.",
                "恶魔阵营获胜：邪恶人数已追平或超过善良人数。"
            )
        case .evilNoWinningPath:
            return (
                "Good wins: evil has no remaining winning line.",
                "善良阵营获胜：邪恶阵营已无获胜路径。"
            )
        }
    }

    var gameOverMessage: String? {
        guard let pair = gameOverMessagePair else { return nil }
        return ui(pair.english, pair.chinese)
    }

    func localizedGameEvent(_ event: GameEvent) -> String {
        let text = ui(event.englishText, event.chineseText)
        return translateEmbeddedRoleNames(text)
    }

    func translateEmbeddedRoleNames(_ text: String) -> String {
        var result = text
        for role in phaseTemplate.roles {
            let englishName = role.name
            let chineseName = role.chineseName
            if isChineseUI {
                result = result.replacingOccurrences(of: englishName, with: chineseName)
            } else {
                result = result.replacingOccurrences(of: chineseName, with: englishName)
            }
        }
        return result
    }

    func color(for logTone: LogTone) -> Color {
        switch logTone {
        case .primary:
            return .primary
        case .transfer:
            return Color(red: 0.2, green: 0.4, blue: 0.8)
        case .poison:
            return Color(uiColor: .systemPurple)
        case .drunk:
            return Color(uiColor: .systemOrange)
        case .noAction:
            return .gray
        case .kill:
            return .red
        }
    }

    func color(for event: GameEvent) -> Color {
        color(for: event.logTone)
    }

    func localizedTemplateName(_ template: ScriptTemplate) -> String {
        isChineseUI ? template.chineseName : template.name
    }

    func localizedRoleName(_ role: RoleTemplate?) -> String {
        guard let role else { return ui("Unassigned role", "未分配角色") }
        return isChineseUI ? role.chineseName : role.name
    }

    func localizedTeamName(_ team: RoleTeam) -> String {
        switch team {
        case .townsfolk:
            return ui("Townsfolk", "镇民")
        case .outsider:
            return ui("Outsider", "外来者")
        case .minion:
            return ui("Minion", "爪牙")
        case .demon:
            return ui("Demon", "恶魔")
        case .traveller:
            return ui("Traveller", "旅人")
        }
    }

    func localizedRoleSummary(_ role: RoleTemplate?) -> String {
        guard let role else { return ui("No role information.", "暂无角色信息。") }
        return isChineseUI ? role.chineseSummary : role.summary
    }

    func localizedRoleDetail(_ role: RoleTemplate?) -> String {
        guard let role else { return ui("No role detail available.", "暂无角色详情。") }
        return isChineseUI ? role.chineseDetail : role.detail
    }

    func roleSummary(_ roleId: String) -> String {
        localizedRoleDetail(roleTemplate(for: roleId))
    }

    func gamePhaseTitle() -> String {
        switch phase {
        case .templateSelection: return ui("Edition", "剧本")
        case .playerSetup: return ui("Players", "玩家")
        case .assignment: return ui("Role Assignment", "角色分配")
        case .impBluffs: return ui("Imp Bluffs", "小恶魔可伪装角色")
        case .impBluffsReveal: return ui("Show Imp Bluffs", "展示小恶魔可伪装角色")
        case .firstNight: return ui("First Night", "第一夜")
        case .night: return ui("Night", "夜晚")
        case .day: return ui("Day", "白天")
        case .finished: return ui("Finished", "结束")
        }
    }

    var currentGrimoireTitle: String {
        isGrimoireShowingBacks
            ? ui("Grimoire: hidden", "魔典：已隐藏")
            : ui("Grimoire: revealed", "魔典：已展开")
    }

    var currentNightOrderSummary: String {
        guard !currentNightSteps.isEmpty else {
            return isFirstNightPhase
                ? ui("First night order has not started.", "第一夜流程未启动")
                : ui("Night order has not started.", "夜晚流程未启动")
        }
        return currentNightSteps.enumerated().map { index, step in
            let roleName = localizedRoleName(roleTemplate(for: step.roleId))
            let playerName = player(for: step.roleId)?.name ?? ui("Not in play", "未上场")
            return "\(index + 1). \(playerName) - \(roleName)"
        }.joined(separator: "｜")
    }
}

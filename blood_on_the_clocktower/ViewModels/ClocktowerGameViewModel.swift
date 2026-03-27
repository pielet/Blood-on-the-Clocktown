import Foundation
import Combine
import SwiftUI

final class ClocktowerGameViewModel: ObservableObject {
    private let roleActionRecordPrefix = "[[role-action]]|"
    private let noOutsiderChoiceID = "__no_outsider__"
    private let nightRoleChoiceRegistrationSeparator = "::registered-by::"

    @Published var templates: [ScriptTemplate]
    private let scriptCatalog: ScriptCatalog
    @Published var selectedTemplateId: String = "trouble-brewing"
    @Published var experimentalEditionIds: Set<String> = []
    @Published var appLanguage: AppLanguage = .chinese

    @Published var phase: PhaseType = .templateSelection
    @Published var playerCount: Int = 7
    @Published var playerNamePrefix: String = "Player"
    @Published var players: [PlayerCard] = []
    @Published var roleDeck: [RoleDeckCard] = []
    @Published var gameLog: [GameEvent] = []
    @Published var nightActionRecords: [NightActionRecord] = []

    @Published var phaseSecondsLeft: Int = 30
    @Published var timerRunning: Bool = false
    @Published var dayPreset: Int = 30

    @Published var currentNightSteps: [NightStepTemplate] = []
    @Published var currentNightStepIndex: Int = 0
    @Published var skippedNightStepIndices: Set<Int> = []
    @Published var isFirstNightPhase: Bool = true
    @Published var currentNightTargets: [UUID] = []
    @Published var currentNightNote: String = ""
    @Published var currentNightAlignmentSelections: [UUID: Bool] = [:]
    @Published var selectedDeckCardId: UUID?
    @Published var selectedAssignmentPlayerId: UUID?
    @Published var isGrimoireShowingBacks: Bool = true
    @Published var revealedGrimoireCardIds: Set<UUID> = []
    @Published var impBluffRoleIds: [String] = []
    @Published var impBluffShownPlayerId: UUID?
    @Published var slayerSelectedTarget: UUID?
    @Published var pendingImpReplacementCandidateIds: [UUID] = []

    @Published var nominatorID: UUID?
    @Published var nomineeID: UUID?
    @Published var pendingVirginRegistrationNominatorId: UUID?
    @Published var pendingSlayerRecluseTargetId: UUID?
    @Published var votesByVoter: [UUID: UUID] = [:]
    @Published var nominationResults: [UUID: Int] = [:]
    @Published var hasExecutionToday: Bool = false
    @Published var executedPlayerToday: UUID?
    @Published var currentDayNumber: Int = 0
    @Published var goblinClaimedPlayerId: UUID?
    @Published var isGameOver: Bool = false
    @Published var winningSide: WinningSide?
    @Published var gameOverReason: GameOverReason?
    @Published var isSelectingFortuneTellerRedHerring: Bool = false

    private var timer: Timer?
    private var pendingNightKill: UUID?
    private var demonProtectedTonight: Set<UUID> = []
    private var protectedTonight: Set<UUID> = []
    private var deadTonight: Set<UUID> = []
    private var demonKilledTonight: Set<UUID> = []
    private var impDiedTonight: Bool = false
    private var demonKillBlockedTonight: Bool = false
    private var exorcisedPlayerId: UUID?
    private var widowPoisonedPlayerId: UUID?
    private var widowKnownPlayerId: UUID?
    private var lleechHostPlayerId: UUID?
    private var grandmotherLinkedPlayerIds: [UUID: UUID] = [:]
    private var fortuneTellerRedHerringId: UUID?
    private var bountyHunterEvilPlayerId: UUID?
    private var bountyHunterKnownPlayerId: UUID?
    private var bountyHunterKnownHistory: Set<UUID> = []
    private var balloonistLastShownType: RoleTeam?
    private var nightwatchmanUsedPlayerIds: Set<UUID> = []
    private var preachedMinionIds: Set<UUID> = []
    private var villageIdiotDrunkPlayerId: UUID?
    private var acrobatTrackedPlayerIds: [UUID: UUID] = [:]
    private var fearmongerTargetByPlayerId: [UUID: UUID] = [:]
    private var harpyMadPlayerId: UUID?
    private var harpyAccusedPlayerId: UUID?
    private var bansheeEmpoweredPlayerIds: Set<UUID> = []
    private var bansheeNominationsUsedByDay: [UUID: Int] = [:]
    private var kingKilledByDemonPlayerId: UUID?
    private var pixieLearnedRoleByPlayerId: [UUID: String] = [:]
    private var alchemistGrantedAbilityRoleId: String?
    private var boffinGrantedAbilityRoleId: String?
    private var xaanNightNumber: Int?
    private var xaanPoisonedUntilDayNumber: Int?
    private var princessProtectedNightAfterDay: Int?
    private var leviathanGoodExecutions: Int = 0
    private var riotActivated: Bool = false
    private var foolSpentPlayerIds: Set<UUID> = []
    private var devilsAdvocateProtectedPlayerId: UUID?
    private var outsiderExecutedToday: Bool = false
    private var pendingForcedNightKills: [UUID] = []
    private var pendingForcedDemonKills: [UUID] = []
    private var assassinUsedPlayerIds: Set<UUID> = []
    private var professorUsedPlayerIds: Set<UUID> = []
    private var courtierUsedPlayerIds: Set<UUID> = []
    private var huntsmanUsedPlayerIds: Set<UUID> = []
    private var seamstressUsedPlayerIds: Set<UUID> = []
    private var poisonerPoisonedPlayerId: UUID?
    private var poisonerPoisonSourcePlayerId: UUID?
    private var pukkaPoisonedPlayerId: UUID?
    private var poChargedPlayerIds: Set<UUID> = []
    private var sweetheartDrunkPlayerId: UUID?
    private var temporaryDrunkPlayerUntilDayNumbers: [UUID: Int] = [:]
    private var temporaryDrunkPlayerSources: [UUID: String] = [:]
    private var temporaryDrunkRoleUntilDayNumbers: [String: Int] = [:]
    private var temporaryDrunkRoleSources: [String: String] = [:]
    private var noDashiiPoisonedPlayerIds: Set<UUID> = []
    private var fangGuJumpUsedPlayerIds: Set<UUID> = []
    private var demonVotedTodayFlag: Bool = false
    private var minionNominatedTodayFlag: Bool = false
    private var didDeathOccurToday: Bool = false
    private var witchCursedPlayerId: UUID?
    private var mastermindExtraDayActive: Bool = false
    private var alignmentOverrides: [UUID: Bool] = [:]
    private var nominationNominatorByNominee: [UUID: UUID] = [:]
    private var artistUsedPlayerIds: Set<UUID> = []
    private var fishermanUsedPlayerIds: Set<UUID> = []
    private var amnesiacUsedByDay: [UUID: Set<Int>] = [:]
    private var engineerUsedPlayerIds: Set<UUID> = []
    private var savantUsedByDay: [UUID: Set<Int>] = [:]
    private var gossipUsedByDay: [UUID: Set<Int>] = [:]
    private var gossipKillTonight: Bool = false
    private var currentActionLogToneOverride: LogTone?
    private var jugglerGuessesByPlayerId: [UUID: String] = [:]
    private var jugglerResolvedPlayerIds: Set<UUID> = []
    private var psychopathUsedByDay: [UUID: Set<Int>] = [:]
    private var wizardUsedPlayerIds: Set<UUID> = []
    private var minstrelDrunkUntilDayNumber: Int?
    private var pacifistSavedPlayerIds: Set<UUID> = []
    private var moonchildPendingPlayerId: UUID?
    private var moonchildPendingTargetId: UUID?
    private var zombuulSpentPlayerIds: Set<UUID> = []
    private var evilTwinPlayerId: UUID?
    private var evilTwinGoodPlayerId: UUID?
    private var vigormortisEmpoweredMinionIds: Set<UUID> = []
    private var vigormortisPoisonedNeighborIds: Set<UUID> = []
    private var selectedBaseTemplate: ScriptTemplate {
        scriptCatalog.baseTemplate(for: selectedTemplateId) ?? templates[0]
    }

    private var phaseTemplate: ScriptTemplate {
        scriptCatalog.template(
            for: selectedTemplateId,
            includingExperimental: experimentalEditionIds.contains(selectedTemplateId)
        ) ?? selectedBaseTemplate
    }

    init() {
        let catalog = ScriptDataLoader.loadCatalog()
        self.scriptCatalog = catalog
        self.templates = catalog.baseTemplates
        phaseSecondsLeft = dayPreset
    }

    var isChineseUI: Bool {
        appLanguage == .chinese
    }

    func ui(_ english: String, _ chinese: String) -> String {
        isChineseUI ? chinese : english
    }

    var appDisplayName: String {
        ui("Storyteller", "说书人")
    }

    var restartButtonTitle: String {
        ui("Restart", "重新开始")
    }

    var hasLeviathanInPlay: Bool {
        players.contains { $0.alive && $0.roleId == "leviathan" }
    }

    var hasLegionInPlay: Bool {
        players.contains { $0.alive && $0.roleId == "legion" }
    }

    var hasRiotInPlay: Bool {
        players.contains { $0.alive && $0.roleId == "riot" }
    }

    var isRiotDay: Bool {
        phase == .day && riotActivated && currentDayNumber >= 3
    }

    private var gameOverMessagePair: (english: String, chinese: String)? {
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

    private func translateEmbeddedRoleNames(_ text: String) -> String {
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

    func color(forRecordedLog text: String) -> Color {
        let localizedText = localizedRecordedLog(text)
        let tone = LogToneClassifier.classify(englishText: text, chineseText: localizedText)
        return color(for: tone)
    }

    func localizedTemplateName(_ template: ScriptTemplate) -> String {
        isChineseUI ? template.chineseName : template.name
    }

    func isExperimentalEnabled(for templateId: String) -> Bool {
        experimentalEditionIds.contains(templateId)
    }

    func setExperimentalEnabled(_ enabled: Bool, for templateId: String) {
        if enabled {
            experimentalEditionIds.insert(templateId)
        } else {
            experimentalEditionIds.remove(templateId)
        }
        if selectedTemplateId == templateId {
            clearDeckDraft()
        }
    }

    func localizedRoleName(_ role: RoleTemplate?) -> String {
        guard let role else { return ui("Unassigned role", "未分配角色") }
        return isChineseUI ? role.chineseName : role.name
    }

    func displayedRole(for player: PlayerCard) -> RoleTemplate? {
        let displayId = player.displayedRoleId ?? player.roleId
        guard let displayId else { return nil }
        return roleTemplate(for: displayId)
    }

    func assignmentDisplayRole(for card: RoleDeckCard) -> RoleTemplate? {
        let displayId: String?
        if card.roleId == "drunk" {
            displayId = card.displayedRoleId
        } else {
            displayId = card.roleId
        }
        guard let displayId else { return nil }
        return roleTemplate(for: displayId)
    }

    var selectedDrunkRoleCard: RoleDeckCard? {
        guard let selectedDeckCardId,
              let card = roleDeck.first(where: { $0.id == selectedDeckCardId }),
              card.state == .front,
              card.roleId == "drunk" else {
            return nil
        }
        return card
    }

    func availableDrunkDisplayRoles(for cardId: UUID) -> [RoleTemplate] {
        let takenShownRoleIds = Set(
            roleDeck
                .filter { $0.roleId == "drunk" && $0.id != cardId }
                .compactMap(\.displayedRoleId)
        )
        let actualRoleIds = Set(roleDeck.map(\.roleId))

        let preferredRoles = phaseTemplate.roles.filter {
            $0.team == .townsfolk &&
            !actualRoleIds.contains($0.id) &&
            !takenShownRoleIds.contains($0.id)
        }
        let fallbackRoles = phaseTemplate.roles.filter {
            $0.team == .townsfolk && !takenShownRoleIds.contains($0.id)
        }
        let source = preferredRoles.isEmpty ? fallbackRoles : preferredRoles

        return source.sorted {
            localizedRoleName($0).localizedStandardCompare(localizedRoleName($1)) == .orderedAscending
        }
    }

    func selectDisplayedRoleForDrunkCard(_ cardId: UUID, roleId: String) {
        guard let deckIndex = roleDeck.firstIndex(where: { $0.id == cardId }),
              roleDeck[deckIndex].roleId == "drunk",
              let selectedRole = roleTemplate(for: roleId),
              selectedRole.team == .townsfolk else {
            return
        }

        roleDeck[deckIndex].displayedRoleId = roleId

        if let assignedPlayerId = roleDeck[deckIndex].assignedPlayerId,
           let playerIndex = players.firstIndex(where: { $0.id == assignedPlayerId }) {
            players[playerIndex].displayedRoleId = roleId
        }
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

    func localizedRecordedReason(_ reason: String) -> String {
        switch reason {
        case "Imp suicide", "小恶魔自杀":
            return ui("Imp suicide", "小恶魔自杀")
        case "Killed by night action", "夜间技能击杀":
            return ui("Killed by night action", "夜间技能击杀")
        case "Slayer shot", "猎手击杀":
            return ui("Slayer shot", "猎手击杀")
        case "Lycanthrope attack", "狼人击杀":
            return ui("Lycanthrope attack", "狼人击杀")
        case "Lleech host died", "利奇宿主死亡":
            return ui("Lleech host died", "利奇宿主死亡")
        case "Executed", "处决":
            return ui("Executed", "处决")
        case "Virgin first nomination", "贞洁者首次被提名":
            return ui("Virgin first nomination", "贞洁者首次被提名")
        default:
            return reason
        }
    }

    func localizedRecordedLog(_ text: String) -> String {
        if let structured = localizedStructuredRoleAction(from: text) {
            return structured
        }

        let exactPairs = [
            ("Became the Demon.", "转变为恶魔。"),
            ("Replacement selected after the Imp died.", "在小恶魔死亡后被选为替代恶魔。"),
            ("Spent the dead vote during day voting.", "在白天投票中用掉了幽灵票。"),
            ("Actually the Drunk. Used a fake Slayer shot.", "真实身份是酒鬼。使用了一次假的猎手射击。"),
            ("Poisoned tonight.", "今夜中毒。"),
            ("Protected this night by the Monk.", "今夜受到僧侣保护。"),
            ("Was chosen as the Butler's master.", "被选为管家的主人。"),
            ("Died as the Imp.", "以小恶魔身份死亡。"),
            ("Returned to life by the Professor.", "被教授复活。"),
            ("The Nightwatchman confirmed themselves to you.", "守夜人向你确认了自己的身份。"),
            ("Learned that a Widow is in play.", "得知本局有寡妇在场。"),
            ("Became Riot.", "转变为暴乱。"),
            ("Survived the first death as the Fool.", "以愚者身份免除了第一次死亡。"),
            ("Survived the first death as the Zombuul.", "以僵怖身份免除了第一次死亡。")
        ]

        if let pair = exactPairs.first(where: { $0.0 == text || $0.1 == text }) {
            return ui(pair.0, pair.1)
        }

        if let delta = text.capture(prefix: "Vote modifier changed by ", suffix: ".") {
            return ui("Vote modifier changed by \(delta).", "投票修正值变化 \(delta)。")
        }
        if let delta = text.capture(prefix: "投票修正值变化 ", suffix: "。") {
            return ui("Vote modifier changed by \(delta).", "投票修正值变化 \(delta)。")
        }

        if let reason = text.capture(prefix: "Died: ", suffix: "") {
            return ui("Died: \(localizedRecordedReason(reason))", "死亡：\(localizedRecordedReason(reason))")
        }
        if let reason = text.capture(prefix: "死亡：", suffix: "") {
            return ui("Died: \(localizedRecordedReason(reason))", "死亡：\(localizedRecordedReason(reason))")
        }

        if let (actor, roleName) = text.captureTwo(before: " skipped ", after: " because of poison.") {
            let localizedRole = localizedRoleNameFromRecordedText(roleName)
            return ui("\(actor) skipped \(localizedRole) because of poison.", "\(actor) 因中毒跳过了 \(localizedRole)。")
        }
        if let (actor, roleName) = text.captureTwo(before: " 因中毒跳过了 ", after: "。") {
            let localizedRole = localizedRoleNameFromRecordedText(roleName)
            return ui("\(actor) skipped \(localizedRole) because of poison.", "\(actor) 因中毒跳过了 \(localizedRole)。")
        }

        if let name = text.capture(prefix: "Confirmed to ", suffix: " as the Nightwatchman.") {
            return ui("Confirmed to \(name) as the Nightwatchman.", "向 \(name) 确认了自己是守夜人。")
        }
        if let name = text.capture(prefix: "向 ", suffix: " 确认了自己是守夜人。") {
            return ui("Confirmed to \(name) as the Nightwatchman.", "向 \(name) 确认了自己是守夜人。")
        }

        if let name = text.capture(prefix: "Learned that ", suffix: " is evil.") {
            return ui("Learned that \(name) is evil.", "得知 \(name) 是邪恶玩家。")
        }
        if let name = text.capture(prefix: "得知 ", suffix: " 是邪恶玩家。") {
            return ui("Learned that \(name) is evil.", "得知 \(name) 是邪恶玩家。")
        }

        if let payload = text.capture(prefix: "Learned a ", suffix: "."),
           let splitIndex = payload.firstIndex(of: ":") {
            let teamName = String(payload[..<splitIndex]).trimmingCharacters(in: .whitespaces)
            let learnedPlayerName = String(payload[payload.index(after: splitIndex)...]).trimmingCharacters(in: .whitespaces)
            let localizedTeam = localizedRecordedTeamName(teamName)
            return ui("Learned a \(localizedTeam): \(learnedPlayerName).", "得知一名\(localizedTeam)：\(learnedPlayerName)。")
        }
        if let payload = text.capture(prefix: "得知一名", suffix: "。"),
           let splitIndex = payload.firstIndex(of: "：") {
            let teamName = String(payload[..<splitIndex])
            let learnedPlayerName = String(payload[payload.index(after: splitIndex)...])
            let localizedTeam = localizedRecordedTeamName(teamName)
            return ui("Learned a \(localizedTeam): \(learnedPlayerName).", "得知一名\(localizedTeam)：\(learnedPlayerName)。")
        }

        if let payload = text.capture(prefix: "Village Idiot learned ", suffix: "."),
           let range = payload.range(of: " is ") {
            let targetName = String(payload[..<range.lowerBound])
            let rawAlignment = String(payload[range.upperBound...])
            let localizedAlignment = localizedRecordedAlignment(rawAlignment)
            return ui("Village Idiot learned \(targetName) is \(localizedAlignment).", "村中傻子得知 \(targetName) 是\(localizedAlignment)阵营。")
        }
        if let payload = text.capture(prefix: "村中傻子得知 ", suffix: "。"),
           let range = payload.range(of: " 是") {
            let targetName = String(payload[..<range.lowerBound])
            let rawAlignment = String(payload[range.upperBound...]).replacingOccurrences(of: "阵营", with: "")
            let localizedAlignment = localizedRecordedAlignment(rawAlignment)
            return ui("Village Idiot learned \(targetName) is \(localizedAlignment).", "村中傻子得知 \(targetName) 是\(localizedAlignment)阵营。")
        }

        if let name = text.capture(prefix: "Used the Slayer shot on ", suffix: " successfully.") {
            return ui("Used the Slayer shot on \(name) successfully.", "成功对 \(name) 发动了猎手技能。")
        }
        if let name = text.capture(prefix: "成功对 ", suffix: " 发动了猎手技能。") {
            return ui("Used the Slayer shot on \(name) successfully.", "成功对 \(name) 发动了猎手技能。")
        }
        if let name = text.capture(prefix: "Used the Slayer shot on ", suffix: " unsuccessfully.") {
            return ui("Used the Slayer shot on \(name) unsuccessfully.", "已对 \(name) 发动猎手技能，但未成功。")
        }
        if let name = text.capture(prefix: "已对 ", suffix: " 发动猎手技能，但未成功。") {
            return ui("Used the Slayer shot on \(name) unsuccessfully.", "已对 \(name) 发动猎手技能，但未成功。")
        }
        if let name = text.capture(prefix: "Actually the Drunk. Used a fake Slayer shot on ", suffix: ".") {
            return ui("Actually the Drunk. Used a fake Slayer shot on \(name).", "真实身份是酒鬼。对 \(name) 使用了一次假的猎手射击。")
        }
        if let name = text.capture(prefix: "真实身份是酒鬼。对 ", suffix: " 使用了一次假的猎手射击。") {
            return ui("Actually the Drunk. Used a fake Slayer shot on \(name).", "真实身份是酒鬼。对 \(name) 使用了一次假的猎手射击。")
        }

        if let (actor, payload) = text.captureTwo(before: " used ", after: "") {
            return localizedUsedRoleLog(actor: actor, payload: payload)
        }
        if let (actor, payload) = text.captureTwo(before: " 使用了 ", after: "") {
            return localizedUsedRoleLog(actor: actor, payload: payload)
        }

        return text
    }

    private func localizedUsedRoleLog(actor: String, payload: String) -> String {
        let noteParts = payload.components(separatedBy: " | ")
        let mainPart = noteParts.first ?? payload
        let note = noteParts.count > 1 ? noteParts.dropFirst().joined(separator: " | ") : ""
        let targetParts = mainPart.components(separatedBy: " -> ")
        let rolePart = targetParts.first ?? mainPart
        let targetText = targetParts.count > 1 ? targetParts.dropFirst().joined(separator: " -> ") : ""
        let localizedRole = localizedRoleNameFromRecordedText(rolePart)
        let targetSuffix = targetText.isEmpty ? "" : " -> \(targetText)"
        let noteSuffix = note.isEmpty ? "" : " | \(note)"
        return ui(
            "\(actor) used \(localizedRole)\(targetSuffix)\(noteSuffix)",
            "\(actor) 使用了 \(localizedRole)\(targetSuffix)\(noteSuffix)"
        )
    }

    private func localizedRecordedTeamName(_ rawName: String) -> String {
        switch rawName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "townsfolk", "镇民":
            return ui("Townsfolk", "镇民")
        case "outsider", "外来者":
            return ui("Outsider", "外来者")
        case "minion", "爪牙":
            return ui("Minion", "爪牙")
        case "demon", "恶魔":
            return ui("Demon", "恶魔")
        case "traveller", "旅人":
            return ui("Traveller", "旅人")
        default:
            return rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    private func localizedRecordedAlignment(_ rawValue: String) -> String {
        switch rawValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "good", "善良":
            return ui("good", "善良")
        case "evil", "邪恶":
            return ui("evil", "邪恶")
        default:
            return rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    private func localizedStructuredRoleAction(from text: String) -> String? {
        guard text.hasPrefix(roleActionRecordPrefix) else { return nil }
        let payload = String(text.dropFirst(roleActionRecordPrefix.count))
        let parts = payload.components(separatedBy: "|")
        guard parts.count >= 4 else { return nil }
        let key = parts[0]
        let actor = parts[1]
        let targetText = parts[2]
        let note = parts[3]

        switch key {
        case "imp-bluffs":
            let roleIds = note.split(separator: ",").map(String.init)
            let bluffNames = roleIds.compactMap { roleTemplate(for: $0) }.map { localizedRoleName($0) }.joined(separator: ", ")
            return ui("Shown Imp bluffs: \(bluffNames).", "展示给小恶魔的可伪装角色：\(bluffNames)。")
        case "acrobat-track":
            return ui("\(actor) chose \(targetText) for Acrobat.", "\(actor) 选择 \(targetText) 作为杂技演员目标。")
        case "alchemist-grant":
            return note.isEmpty ? ui("\(actor) used Alchemist.", "\(actor) 使用了炼金术士能力。") : ui("\(actor) gained the \(localizedRoleNameFromRecordedText(note)) ability as Alchemist.", "\(actor) 作为炼金术士获得了 \(localizedRoleNameFromRecordedText(note)) 能力。")
        case "steward-info":
            return ui("\(actor) learned 1 good player.", "\(actor) 得知了 1 名善良玩家。")
        case "noble-info":
            return ui("\(actor) learned 3 players with exactly 1 evil.", "\(actor) 得知了 3 名玩家，其中恰有 1 名邪恶。")
        case "knight-info":
            return ui("\(actor) learned 2 players that are not the Demon.", "\(actor) 得知了 2 名不是恶魔的玩家。")
        case "shugenja-info":
            return ui("\(actor) learned which direction the nearest evil lies.", "\(actor) 得知了最近邪恶的大致方向。")
        case "pixie-info":
            return ui("\(actor) learned an in-play Townsfolk.", "\(actor) 得知了一名在场镇民。")
        case "high-priestess-info":
            return ui("\(actor) was guided to a player by High Priestess.", "\(actor) 以女祭司能力被引导到一名玩家。")
        case "king-info":
            return ui("\(actor) learned an alive character.", "\(actor) 得知了一个存活角色。")
        case "choirboy-info":
            return ui("\(actor) learned the Demon because the King died.", "\(actor) 因国王死亡而得知了恶魔。")
        case "boffin-grant":
            return note.isEmpty ? ui("\(actor) used Boffin.", "\(actor) 使用了博芬能力。") : ui("\(actor) granted the Demon the \(localizedRoleNameFromRecordedText(note)) ability.", "\(actor) 让恶魔获得了 \(localizedRoleNameFromRecordedText(note)) 能力。")
        case "grandmother-link":
            return ui("\(actor) learned that \(targetText) is their good player.", "\(actor) 得知 \(targetText) 是自己的祖母目标。")
        case "sailor-drink":
            return ui("\(actor) chose \(targetText) for the Sailor ability.", "\(actor) 用水手能力选择了 \(targetText)。")
        case "chambermaid-check":
            return ui("\(actor) compared whether \(targetText) woke tonight.", "\(actor) 查看 \(targetText) 今晚是否醒来。")
        case "exorcist-target":
            return ui("\(actor) chose \(targetText) for the Exorcist check.", "\(actor) 选择 \(targetText) 作为驱魔目标。")
        case "innkeeper-protect":
            return ui("\(actor) protected \(targetText) as the Innkeeper.", "\(actor) 以店主能力保护了 \(targetText)。")
        case "gambler-guess":
            let localizedGuess = localizedRoleNameFromRecordedText(note)
            return note.isEmpty
                ? ui("\(actor) gambled on \(targetText).", "\(actor) 对 \(targetText) 发动了赌徒能力。")
                : ui("\(actor) guessed \(localizedGuess) for \(targetText).", "\(actor) 猜测 \(targetText) 是 \(localizedGuess)。")
        case "courtier-drunk":
            let localizedChoice = localizedRoleNameFromRecordedText(note)
            return ui("\(actor) chose \(localizedChoice) for the Courtier ability.", "\(actor) 用朝臣能力选择了 \(localizedChoice)。")
        case "professor-revive":
            return ui("\(actor) chose \(targetText) for resurrection.", "\(actor) 选择复活 \(targetText)。")
        case "devils-advocate-protect":
            return ui("\(actor) protected \(targetText) from tomorrow's execution.", "\(actor) 保护 \(targetText) 免于明日处决死亡。")
        case "cultleader-align":
            return ui("\(actor) resolved Cult Leader alignment.", "\(actor) 结算了邪教领袖阵营。")
        case "huntsman-check":
            return ui("\(actor) chose \(targetText) for Huntsman.", "\(actor) 选择 \(targetText) 作为猎人目标。")
        case "witch-curse":
            return ui("\(actor) cursed \(targetText).", "\(actor) 诅咒了 \(targetText)。")
        case "assassin-attack":
            return ui("\(actor) targeted \(targetText) with the Assassin ability.", "\(actor) 用刺客能力指定了 \(targetText)。")
        case "fearmonger-target":
            return ui("\(actor) chose \(targetText) as the Fearmonger target.", "\(actor) 选择 \(targetText) 作为恐惧贩子的目标。")
        case "godfather-kill":
            return ui("\(actor) chose \(targetText) for the Godfather kill.", "\(actor) 选择 \(targetText) 作为教父夜杀目标。")
        case "godfather-none":
            return ui("\(actor) had no Godfather kill tonight.", "\(actor) 今夜教父没有额外击杀。")
        case "nightwatchman-confirm":
            return ui("\(actor) confirmed to \(targetText) as the Nightwatchman.", "\(actor) 向 \(targetText) 确认了自己是守夜人。")
        case "lunatic-fake-kill":
            return ui("\(actor) chose \(targetText) as a fake Demon target.", "\(actor) 选择 \(targetText) 作为假恶魔目标。")
        case "bountyhunter-info":
            return ui("\(actor) learned another evil player.", "\(actor) 得知了另一名邪恶玩家。")
        case "balloonist-info":
            return ui("\(actor) learned a player of a new character type.", "\(actor) 得知了一名不同角色类型的玩家。")
        case "general-info":
            return ui("\(actor) received the General result.", "\(actor) 收到了将军结果。")
        case "mezepheles-word":
            return note.isEmpty ? ui("\(actor) set a Mezepheles word.", "\(actor) 设定了梅泽菲勒斯单词。") : ui("\(actor) set the Mezepheles word: \(note).", "\(actor) 设定了梅泽菲勒斯单词：\(note)。")
        case "organgrinder-secret":
            return ui("\(actor) resolved Organ Grinder secrecy.", "\(actor) 结算了风琴师秘密投票。")
        case "villageidiot-check":
            return ui("\(actor) checked \(targetText)'s alignment.", "\(actor) 查看了 \(targetText) 的阵营。")
        case "poisoner-poison":
            return ui("\(actor) poisoned \(targetText).", "\(actor) 使 \(targetText) 中毒。")
        case "widow-poison":
            return ui("\(actor) chose \(targetText) as the Widow poison target.", "\(actor) 选择 \(targetText) 作为寡妇的投毒目标。")
        case "monk-protect":
            return ui("\(actor) protected \(targetText).", "\(actor) 保护了 \(targetText)。")
        case "butler-master":
            return ui("\(actor) chose \(targetText) as master.", "\(actor) 选择 \(targetText) 作为主人。")
        case "imp-kill":
            return ui("\(actor) chose \(targetText) for the Imp kill.", "\(actor) 选择 \(targetText) 作为小恶魔夜杀目标。")
        case "imp-suicide":
            return ui("\(actor) chose self for Imp suicide.", "\(actor) 选择自己进行小恶魔自杀。")
        case "lleech-host":
            return ui("\(actor) chose \(targetText) as host.", "\(actor) 选择 \(targetText) 作为宿主。")
        case "lleech-kill":
            return ui("\(actor) chose \(targetText) for the Lleech kill.", "\(actor) 选择 \(targetText) 作为利奇夜杀目标。")
        case "lycanthrope-attack":
            return ui("\(actor) targeted \(targetText) with the Lycanthrope ability.", "\(actor) 用狼人能力指定了 \(targetText)。")
        case "preacher-choose":
            return ui("\(actor) preached to \(targetText).", "\(actor) 向 \(targetText) 布道。")
        case "ravenkeeper-check":
            return ui("\(actor) inspected \(targetText) as the Ravenkeeper.", "\(actor) 作为守鸦人查看了 \(targetText)。")
        case "undertaker-info":
            if targetText.isEmpty || note.isEmpty {
                return ui("\(actor) received the Undertaker result.", "\(actor) 收到了送葬者结果。")
            }
            let undertakerRole = localizedRoleNameFromRecordedText(note)
            return ui(
                "\(actor) learned that \(targetText) was the \(undertakerRole).",
                "\(actor) 得知 \(targetText) 的真实角色是 \(undertakerRole)。"
            )
        case "oracle-info":
            return ui("\(actor) received the Oracle result.", "\(actor) 收到了神谕者结果。")
        case "flowergirl-info":
            return ui("\(actor) received the Flowergirl result.", "\(actor) 收到了卖花女结果。")
        case "town-crier-info":
            return ui("\(actor) received the Town Crier result.", "\(actor) 收到了传令官结果。")
        case "seamstress-check":
            return ui("\(actor) compared \(targetText).", "\(actor) 比较了 \(targetText) 的阵营。")
        case "juggler-info":
            return ui("\(actor) received the Juggler result.", "\(actor) 收到了杂耍演员结果。")
        case "fortuneteller-check":
            return ui("\(actor) checked \(targetText) as the Fortune Teller.", "\(actor) 作为占卜师查看了 \(targetText)。")
        case "empath-info":
            return note.isEmpty ? ui("\(actor) received the Empath result.", "\(actor) 收到了共情者结果。") : ui("\(actor) received the Empath result: \(note)", "\(actor) 收到了共情者结果：\(note)")
        case "chef-info":
            return note.isEmpty ? ui("\(actor) received the Chef result.", "\(actor) 收到了厨师结果。") : ui("\(actor) received the Chef result: \(note)", "\(actor) 收到了厨师结果：\(note)")
        case "washerwoman-info":
            let washerwomanRole = localizedRoleNameFromRecordedText(note)
            let registrationSuffix = troubleBrewingRegistrationLogSuffix(from: note)
            return targetText.isEmpty
                ? ui("\(actor) learned the \(washerwomanRole).\(registrationSuffix.english)", "\(actor) 得知了 \(washerwomanRole)。\(registrationSuffix.chinese)")
                : ui("\(actor) learned that one of \(targetText) is the \(washerwomanRole).\(registrationSuffix.english)", "\(actor) 得知 \(targetText) 之中有一人是 \(washerwomanRole)。\(registrationSuffix.chinese)")
        case "librarian-info":
            if note == noOutsiderChoiceID {
                return ui("\(actor) learned there is no Outsider in play.", "\(actor) 得知场上没有外来者。")
            }
            let librarianRole = localizedRoleNameFromRecordedText(note)
            let registrationSuffix = troubleBrewingRegistrationLogSuffix(from: note)
            return targetText.isEmpty
                ? ui("\(actor) learned the \(librarianRole).\(registrationSuffix.english)", "\(actor) 得知了 \(librarianRole)。\(registrationSuffix.chinese)")
                : ui("\(actor) learned that one of \(targetText) is the \(librarianRole).\(registrationSuffix.english)", "\(actor) 得知 \(targetText) 之中有一人是 \(librarianRole)。\(registrationSuffix.chinese)")
        case "investigator-info":
            let investigatorRole = localizedRoleNameFromRecordedText(note)
            let registrationSuffix = troubleBrewingRegistrationLogSuffix(from: note)
            return targetText.isEmpty
                ? ui("\(actor) learned the \(investigatorRole).\(registrationSuffix.english)", "\(actor) 得知了 \(investigatorRole)。\(registrationSuffix.chinese)")
                : ui("\(actor) learned that one of \(targetText) is the \(investigatorRole).\(registrationSuffix.english)", "\(actor) 得知 \(targetText) 之中有一人是 \(investigatorRole)。\(registrationSuffix.chinese)")
        case "first-night-info":
            return note.isEmpty ? ui("\(actor) received a first-night information result.", "\(actor) 收到了首夜信息结果。") : ui("\(actor) received a first-night information result: \(note)", "\(actor) 收到了首夜信息结果：\(note)")
        case "spy-grimoire":
            return ui("\(actor) checked the Grimoire.", "\(actor) 查看了魔典。")
        case "pukka-poison":
            return ui("\(actor) poisoned \(targetText) as Pukka.", "\(actor) 以普卡之力毒了 \(targetText)。")
        case "alhadikhia-choice":
            return ui("\(actor) chose \(targetText) for Al-Hadikhia.", "\(actor) 为阿尔哈迪基亚选择了 \(targetText)。")
        case "shabaloth-kill":
            return ui("\(actor) chose \(targetText) for the Shabaloth kill.", "\(actor) 选择 \(targetText) 作为沙巴洛斯夜杀目标。")
        case "legion-kill":
            return ui("\(actor) resolved Legion on \(targetText).", "\(actor) 对 \(targetText) 结算了军团能力。")
        case "lilmonsta-night":
            return ui("\(actor) resolved Lil' Monsta. \(note)", "\(actor) 结算了小怪物。\(note)")
        case "po-kill":
            return ui("\(actor) chose \(targetText) for the Po kill.", "\(actor) 选择 \(targetText) 作为波的夜杀目标。")
        case "po-charge":
            return ui("\(actor) skipped the kill to charge Po.", "\(actor) 放弃击杀，为波蓄力。")
        case "snake-charmer-check":
            return ui("\(actor) charmed \(targetText).", "\(actor) 对 \(targetText) 发动了驯蛇。")
        case "fang-gu-jump":
            return ui("\(actor) jumped to \(targetText) as Fang Gu.", "\(actor) 将方固转移给了 \(targetText)。")
        case "fang-gu-kill":
            return ui("\(actor) chose \(targetText) for the Fang Gu kill.", "\(actor) 选择 \(targetText) 作为方固夜杀目标。")
        case "vigormortis-kill":
            return ui("\(actor) chose \(targetText) for the Vigormortis kill.", "\(actor) 选择 \(targetText) 作为维戈莫提斯夜杀目标。")
        case "no-dashii-kill":
            return ui("\(actor) chose \(targetText) for the No Dashii kill.", "\(actor) 选择 \(targetText) 作为诺达希夜杀目标。")
        case "lordoftyphon-kill":
            return ui("\(actor) chose \(targetText) for the Lord of Typhon kill.", "\(actor) 选择 \(targetText) 作为提丰之主夜杀目标。")
        case "ojo-guess":
            return note.isEmpty ? ui("\(actor) used Ojo.", "\(actor) 发动了奥霍能力。") : ui("\(actor) chose \(note) for Ojo.", "\(actor) 为奥霍选择了 \(note)。")
        case "yaggababble-phrase":
            return note.isEmpty ? ui("\(actor) recorded a Yaggababble phrase.", "\(actor) 记录了一条亚嘎巴布尔短语。") : ui("\(actor) recorded the Yaggababble phrase: \(note).", "\(actor) 记录了亚嘎巴布尔短语：\(note)。")
        case "zombuul-kill":
            return ui("\(actor) chose \(targetText) for the Zombuul kill.", "\(actor) 选择 \(targetText) 作为僵怖夜杀目标。")
        case "zombuul-none":
            return ui("\(actor) had no Zombuul kill tonight.", "\(actor) 今夜没有僵怖击杀。")
        case "pit-hag-transform":
            return note.isEmpty ? ui("\(actor) transformed \(targetText).", "\(actor) 变形了 \(targetText)。") : ui("\(actor) transformed \(targetText) into \(note).", "\(actor) 将 \(targetText) 变为 \(note)。")
        case "evil-twin-link":
            return ui("\(actor) checked the Evil Twin link.", "\(actor) 结算了邪恶双子连接。")
        case "engineer-change":
            return note.isEmpty ? ui("\(actor) used Engineer.", "\(actor) 使用了工程师能力。") : ui("\(actor) changed the evil roles to \(note).", "\(actor) 将邪恶角色改为 \(note)。")
        case "summoner-create":
            return note.isEmpty ? ui("\(actor) used Summoner on \(targetText).", "\(actor) 对 \(targetText) 使用了召唤师能力。") : ui("\(actor) summoned \(targetText) as \(localizedRoleNameFromRecordedText(note)).", "\(actor) 将 \(targetText) 召唤为 \(localizedRoleNameFromRecordedText(note))。")
        case "wizard-wish":
            return note.isEmpty ? ui("\(actor) made a Wizard wish.", "\(actor) 许下了巫师愿望。") : ui("\(actor) made the Wizard wish: \(note).", "\(actor) 许下了巫师愿望：\(note)。")
        case "xaan-night":
            return ui("\(actor) marked the Xaan poison night.", "\(actor) 标记了夏安投毒之夜。")
        case "scarletwoman-check":
            return ui("\(actor) checked Scarlet Woman demon replacement effects.", "\(actor) 结算了红唇女郎的恶魔替换效果。")
        case "dreamer-info":
            return targetText.isEmpty
                ? ui("\(actor) used Dreamer ability.", "\(actor) 使用了梦想家能力。")
                : ui("\(actor) chose \(targetText). Shown: \(note).", "\(actor) 选择了 \(targetText)。展示：\(note)。")
        case "mathematician-info":
            return ui("\(actor) learned the number: \(note.isEmpty ? "0" : note).", "\(actor) 得知数字：\(note.isEmpty ? "0" : note)。")
        case "vortox-kill":
            return targetText.isEmpty
                ? ui("\(actor) had no Vortox kill.", "\(actor) 今夜没有沃托克斯击杀。")
                : ui("\(actor) chose \(targetText) for Vortox kill.", "\(actor) 选择 \(targetText) 作为沃托克斯夜杀目标。")
        default:
            return ui("\(actor) used an ability.", "\(actor) 发动了一次能力。")
        }
    }

    private func localizedRoleNameFromRecordedText(_ rawName: String) -> String {
        let trimmed = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        let parsedRoleId = decodedNightRoleChoice(from: trimmed).roleId ?? trimmed
        if let role = phaseTemplate.roles.first(where: {
            $0.id == parsedRoleId || $0.name == parsedRoleId || $0.chineseName == parsedRoleId
        }) {
            return localizedRoleName(role)
        }
        return parsedRoleId
    }

    private func encodedNightRoleChoiceId(roleId: String?, registeringPlayerId: UUID?) -> String {
        guard let roleId else { return noOutsiderChoiceID }
        guard let registeringPlayerId else { return roleId }
        return "\(roleId)\(nightRoleChoiceRegistrationSeparator)\(registeringPlayerId.uuidString)"
    }

    private func decodedNightRoleChoice(from choiceId: String) -> (roleId: String?, registeringPlayerId: UUID?) {
        let trimmed = choiceId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return (nil, nil) }
        if trimmed == noOutsiderChoiceID {
            return (nil, nil)
        }
        let parts = trimmed.components(separatedBy: nightRoleChoiceRegistrationSeparator)
        guard let roleId = parts.first, !roleId.isEmpty else { return (nil, nil) }
        let registeringPlayerId = parts.count > 1 ? UUID(uuidString: parts[1]) : nil
        return (roleId, registeringPlayerId)
    }

    private func troubleBrewingRegistrationLogSuffix(from note: String) -> (english: String, chinese: String) {
        let parsedChoice = decodedNightRoleChoice(from: note)
        guard let shownRoleId = parsedChoice.roleId,
              let registeringPlayerId = parsedChoice.registeringPlayerId,
              let registeringPlayer = playerLookup(by: registeringPlayerId),
              let shownRole = roleTemplate(for: shownRoleId) else {
            return ("", "")
        }

        if let actualRole = roleTemplate(for: registeringPlayer.roleId ?? "") {
            return (
                " \(registeringPlayer.name) (\(actualRole.name)) registered as the \(shownRole.name).",
                " \(registeringPlayer.name)（\(actualRole.chineseName)）登记为 \(shownRole.chineseName)。"
            )
        }

        return (
            " \(registeringPlayer.name) registered as the \(shownRole.name).",
            " \(registeringPlayer.name) 登记为 \(shownRole.chineseName)。"
        )
    }

    private func playerActsAsRole(_ player: PlayerCard, roleId: String) -> Bool {
        player.roleId == roleId || (player.roleId == "drunk" && player.displayedRoleId == roleId)
    }

    private func isDisplayedDrunk(_ player: PlayerCard, actingAs roleId: String) -> Bool {
        player.roleId == "drunk" && player.displayedRoleId == roleId
    }

    private func apparentRoleId(for player: PlayerCard) -> String? {
        if let displayedRoleId = player.displayedRoleId, player.roleId == "drunk" {
            return displayedRoleId
        }
        return player.roleId
    }

    private func apparentRoleName(for player: PlayerCard, fallbackRoleId: String? = nil) -> String {
        let roleId = fallbackRoleId ?? apparentRoleId(for: player)
        return localizedRoleName(roleId.flatMap { roleTemplate(for: $0) })
    }

    private func actingPlayer(
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

    private func isCurrentNightDisplayedDrunk(for roleId: String? = nil) -> Bool {
        guard let actor = currentNightActor else { return false }
        let expectedRoleId = roleId ?? currentNightStep?.roleId
        guard let expectedRoleId else { return false }
        return isDisplayedDrunk(actor, actingAs: expectedRoleId)
    }

    private func currentNightDrunkGuidance(roleId: String) -> String? {
        guard let actor = currentNightActor, isDisplayedDrunk(actor, actingAs: roleId) else { return nil }
        let role = roleTemplate(for: roleId)
        let engName = role?.name ?? roleId
        let chnName = role?.chineseName ?? roleId
        return ui(
            "\(actor.name) is actually the Drunk. Wake them as \(engName), but give false information and apply no real effect.",
            "\(actor.name) 的真实身份是酒鬼。请按 \(chnName) 唤醒，但给出错误信息，且不要产生真实效果。"
        )
    }

    private func currentNightSuppressionGuidance(roleId: String) -> String? {
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

    private func currentNightReminderHighlightStyle(for roleId: String) -> NightReminderHighlightStyle? {
        guard let actor = currentNightActor else { return nil }
        if playerIsPoisoned(actor) {
            return .poison
        }
        if isDisplayedDrunk(actor, actingAs: roleId) || isPlayerExternallyPoisonedOrDrunk(actor) {
            return .drunk
        }
        return nil
    }

    private func actingDayPlayer(for roleId: String, requireUnsuppressed: Bool = true) -> PlayerCard? {
        actingPlayer(for: roleId, requireAlive: true, requireUnsuppressed: requireUnsuppressed)
    }

    private func markDisplayedDrunkNightUsage(actor: PlayerCard, roleId: String) {
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

    private func handleDisplayedDrunkTroubleBrewingFirstNightInfo(
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

    private func handleDisplayedDrunkNightAction(
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

    private func appendUniqueStatus(_ items: inout [String], _ value: String?) {
        guard let value, !items.contains(value) else { return }
        items.append(value)
    }

    private func persistentPoisonStatus(for player: PlayerCard) -> String? {
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

    private func persistentDrunkStatus(for player: PlayerCard) -> String? {
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

    private func isSuppressedByPreacher(_ player: PlayerCard) -> Bool {
        preachedMinionIds.contains(player.id) &&
        players.contains(where: { $0.alive && $0.roleId == "preacher" && !playerIsPoisonedOrDrunk($0) })
    }

    // MARK: - Setup

    func startTemplateSelection() {
        phase = .templateSelection
    }

    func selectTemplate(_ templateId: String) {
        selectedTemplateId = templateId
        clearDeckDraft()
        phase = .playerSetup
    }

    func setPlayerCount(_ count: Int) {
        let sanitized = max(5, min(20, count))
        guard sanitized != playerCount else { return }
        playerCount = sanitized
        clearDeckDraft()
    }

    var expectedTeamDistribution: String {
        let counts = phaseTemplate.countTarget(for: playerCount)
        return ui(
            "Townsfolk \(counts.townsfolk), Outsiders \(counts.outsiders), Minions \(counts.minions), Demons \(counts.demons)",
            "镇民 \(counts.townsfolk)，外来者 \(counts.outsiders)，爪牙 \(counts.minions)，恶魔 \(counts.demons)"
        )
    }

    var selectedDeckTeamDistribution: String {
        guard !roleDeck.isEmpty else { return expectedTeamDistribution }
        let counts = deckTeamCounts()
        return ui(
            "Townsfolk \(counts.townsfolk), Outsiders \(counts.outsiders), Minions \(counts.minions), Demons \(counts.demons)",
            "镇民 \(counts.townsfolk)，外来者 \(counts.outsiders)，爪牙 \(counts.minions)，恶魔 \(counts.demons)"
        )
    }

    var templateSummary: String {
        let counts = phaseTemplate.countTarget(for: playerCount)
        return "T \(counts.townsfolk), O \(counts.outsiders), M \(counts.minions), D \(counts.demons)"
    }

    var drunkCards: [RoleDeckCard] {
        roleDeck.filter { $0.roleId == "drunk" }
    }

    var impPlayerForSetup: PlayerCard? {
        if let impBluffShownPlayerId,
           let player = playerLookup(by: impBluffShownPlayerId) {
            return player
        }
        return players.first(where: { $0.roleId == "imp" })
    }

    var availableImpBluffRoles: [RoleTemplate] {
        let hasDrunkInPlay = players.contains { $0.roleId == "drunk" }
        let usedRoleIds = Set(players.compactMap(\.roleId))
            .union(players.compactMap { player in
                player.roleId == "drunk" ? player.displayedRoleId : nil
            })

        return phaseTemplate.roles
            .filter { role in
                (role.team == .townsfolk || role.team == .outsider) &&
                (hasDrunkInPlay || role.id != "drunk") &&
                !usedRoleIds.contains(role.id)
            }
            .sorted {
                localizedRoleName($0).localizedStandardCompare(localizedRoleName($1)) == .orderedAscending
            }
    }

    var selectedImpBluffRoles: [RoleTemplate] {
        impBluffRoleIds.compactMap { roleTemplate(for: $0) }
    }

    var impBluffSelectionTargetCount: Int {
        min(3, availableImpBluffRoles.count)
    }

    var isImpBluffSelectionReady: Bool {
        impBluffRoleIds.count == impBluffSelectionTargetCount && impBluffSelectionTargetCount > 0
    }

    var shouldShowImpBluffSetup: Bool {
        impPlayerForSetup != nil && impBluffSelectionTargetCount > 0
    }

    var pendingImpReplacementCandidates: [PlayerCard] {
        pendingImpReplacementCandidateIds
            .compactMap(playerLookup(by:))
            .sorted { $0.seatNumber < $1.seatNumber }
    }

    var isAwaitingImpReplacementSelection: Bool {
        !pendingImpReplacementCandidateIds.isEmpty
    }

    var canStartRoleAssignment: Bool {
        !roleDeck.isEmpty && drunkCards.allSatisfy { $0.displayedRoleId != nil }
    }

    func templateSummary(for template: ScriptTemplate) -> String {
        let counts = template.countTarget(for: playerCount)
        return "T \(counts.townsfolk), O \(counts.outsiders), M \(counts.minions), D \(counts.demons)"
    }

    func playerSetup() {
        if roleDeck.isEmpty {
            buildDeck()
        }
        players = (1...playerCount).map { seat in
            PlayerCard(
                id: UUID(),
                seatNumber: seat,
                name: "\(playerNamePrefix)\(seat)",
                roleId: nil,
                originalRoleId: nil,
                displayedRoleId: nil,
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
        gameLog.removeAll()
        roleDeck = roleDeck.shuffled().map {
            RoleDeckCard(roleId: $0.roleId, assignedPlayerId: nil, displayedRoleId: $0.displayedRoleId, state: .back)
        }
        revealedGrimoireCardIds.removeAll()
        nightActionRecords.removeAll()
        selectedDeckCardId = nil
        selectedAssignmentPlayerId = players.first?.id
        impBluffRoleIds.removeAll()
        impBluffShownPlayerId = nil
        pendingImpReplacementCandidateIds.removeAll()
        isGrimoireShowingBacks = true
        isGameOver = false
        winningSide = nil
        gameOverReason = nil
        phase = .assignment
    }

    func resetGame() {
        timer?.invalidate()
        timer = nil
        timerRunning = false
        phase = .templateSelection
        players.removeAll()
        roleDeck.removeAll()
        revealedGrimoireCardIds.removeAll()
        gameLog.removeAll()
        nightActionRecords.removeAll()
        currentNightSteps.removeAll()
        currentNightStepIndex = 0
        skippedNightStepIndices.removeAll()
        currentNightTargets.removeAll()
        currentNightNote = ""
        currentNightAlignmentSelections.removeAll()
        currentDayNumber = 0
        demonProtectedTonight.removeAll()
        nominatorID = nil
        goblinClaimedPlayerId = nil
        widowPoisonedPlayerId = nil
        widowKnownPlayerId = nil
        lleechHostPlayerId = nil
        grandmotherLinkedPlayerIds.removeAll()
        demonKillBlockedTonight = false
        exorcisedPlayerId = nil
        bountyHunterEvilPlayerId = nil
        bountyHunterKnownPlayerId = nil
        bountyHunterKnownHistory.removeAll()
        balloonistLastShownType = nil
        nightwatchmanUsedPlayerIds.removeAll()
        preachedMinionIds.removeAll()
        villageIdiotDrunkPlayerId = nil
        acrobatTrackedPlayerIds.removeAll()
        fearmongerTargetByPlayerId.removeAll()
        harpyMadPlayerId = nil
        harpyAccusedPlayerId = nil
        bansheeEmpoweredPlayerIds.removeAll()
        bansheeNominationsUsedByDay.removeAll()
        kingKilledByDemonPlayerId = nil
        pixieLearnedRoleByPlayerId.removeAll()
        alchemistGrantedAbilityRoleId = nil
        boffinGrantedAbilityRoleId = nil
        xaanNightNumber = nil
        xaanPoisonedUntilDayNumber = nil
        princessProtectedNightAfterDay = nil
        leviathanGoodExecutions = 0
        riotActivated = false
        foolSpentPlayerIds.removeAll()
        devilsAdvocateProtectedPlayerId = nil
        outsiderExecutedToday = false
        pendingForcedNightKills.removeAll()
        pendingForcedDemonKills.removeAll()
        assassinUsedPlayerIds.removeAll()
        professorUsedPlayerIds.removeAll()
        courtierUsedPlayerIds.removeAll()
        huntsmanUsedPlayerIds.removeAll()
        seamstressUsedPlayerIds.removeAll()
        poisonerPoisonedPlayerId = nil
        poisonerPoisonSourcePlayerId = nil
        pukkaPoisonedPlayerId = nil
        poChargedPlayerIds.removeAll()
        sweetheartDrunkPlayerId = nil
        temporaryDrunkPlayerUntilDayNumbers.removeAll()
        temporaryDrunkPlayerSources.removeAll()
        temporaryDrunkRoleUntilDayNumbers.removeAll()
        temporaryDrunkRoleSources.removeAll()
        noDashiiPoisonedPlayerIds.removeAll()
        fangGuJumpUsedPlayerIds.removeAll()
        demonVotedTodayFlag = false
        minionNominatedTodayFlag = false
        didDeathOccurToday = false
        witchCursedPlayerId = nil
        mastermindExtraDayActive = false
        alignmentOverrides.removeAll()
        nominationNominatorByNominee.removeAll()
        artistUsedPlayerIds.removeAll()
        fishermanUsedPlayerIds.removeAll()
        amnesiacUsedByDay.removeAll()
        engineerUsedPlayerIds.removeAll()
        savantUsedByDay.removeAll()
        gossipUsedByDay.removeAll()
        gossipKillTonight = false
        jugglerGuessesByPlayerId.removeAll()
        jugglerResolvedPlayerIds.removeAll()
        psychopathUsedByDay.removeAll()
        wizardUsedPlayerIds.removeAll()
        minstrelDrunkUntilDayNumber = nil
        pacifistSavedPlayerIds.removeAll()
        moonchildPendingPlayerId = nil
        moonchildPendingTargetId = nil
        zombuulSpentPlayerIds.removeAll()
        evilTwinPlayerId = nil
        evilTwinGoodPlayerId = nil
        vigormortisEmpoweredMinionIds.removeAll()
        vigormortisPoisonedNeighborIds.removeAll()
        nomineeID = nil
        votesByVoter.removeAll()
        nominationResults.removeAll()
        hasExecutionToday = false
        executedPlayerToday = nil
        isGameOver = false
        winningSide = nil
        gameOverReason = nil
        isFirstNightPhase = true
        selectedDeckCardId = nil
        selectedAssignmentPlayerId = nil
        impBluffRoleIds.removeAll()
        impBluffShownPlayerId = nil
        pendingImpReplacementCandidateIds.removeAll()
        isGrimoireShowingBacks = true
    }

    func updatePlayerName(_ playerID: UUID, name: String) {
        guard let idx = players.firstIndex(where: { $0.id == playerID }) else { return }
        players[idx].name = name.isEmpty ? "\(playerNamePrefix)\(players[idx].seatNumber)" : name
    }

    // MARK: - Deck and assignment

    func clearDeckDraft() {
        roleDeck.removeAll()
        revealedGrimoireCardIds.removeAll()
        currentNightSteps.removeAll()
        currentNightStepIndex = 0
        currentNightTargets.removeAll()
        currentNightNote = ""
        currentNightAlignmentSelections.removeAll()
        selectedDeckCardId = nil
        selectedAssignmentPlayerId = nil
        impBluffRoleIds.removeAll()
        impBluffShownPlayerId = nil
        pendingImpReplacementCandidateIds.removeAll()
        widowPoisonedPlayerId = nil
        widowKnownPlayerId = nil
        lleechHostPlayerId = nil
        demonKillBlockedTonight = false
        exorcisedPlayerId = nil
        gossipKillTonight = false
        acrobatTrackedPlayerIds.removeAll()
        harpyMadPlayerId = nil
        harpyAccusedPlayerId = nil
        kingKilledByDemonPlayerId = nil
        princessProtectedNightAfterDay = nil
        xaanPoisonedUntilDayNumber = nil
    }

    private func deckTeamCounts() -> (townsfolk: Int, outsiders: Int, minions: Int, demons: Int) {
        roleDeck.reduce(into: (townsfolk: 0, outsiders: 0, minions: 0, demons: 0)) { result, card in
            guard let role = roleTemplate(for: card.roleId) else { return }
            switch role.team {
            case .townsfolk:
                result.townsfolk += 1
            case .outsider:
                result.outsiders += 1
            case .minion:
                result.minions += 1
            case .demon:
                result.demons += 1
            case .traveller:
                break
            }
        }
    }

    func buildDeck() {
        let counts = phaseTemplate.countTarget(for: playerCount)
        let rolesByTeam = Dictionary(grouping: phaseTemplate.roles, by: { $0.team })
        let towns = rolesByTeam[.townsfolk] ?? []
        let outsiders = rolesByTeam[.outsider] ?? []
        let minions = rolesByTeam[.minion] ?? []
        let demons = rolesByTeam[.demon] ?? []
        let chosenDemons = pickUniqueRoleIds(from: demons, count: counts.demons)
        if chosenDemons.contains("legion") {
            let goodCount = max(2, counts.minions + counts.demons)
            let outsiderCount = min(counts.outsiders, goodCount)
            let townsfolkCount = max(0, goodCount - outsiderCount)
            let chosenTowns = pickUniqueRoleIds(from: towns, count: townsfolkCount)
            let chosenOutsiders = pickUniqueRoleIds(from: outsiders, count: outsiderCount)
            var selectedRoles = chosenTowns + chosenOutsiders + Array(repeating: "legion", count: max(1, playerCount - goodCount))
            selectedRoles = Array(selectedRoles.prefix(playerCount))
            roleDeck = selectedRoles.shuffled().map { RoleDeckCard(roleId: $0, assignedPlayerId: nil, state: .back) }
            gameLog.removeAll()
            nightActionRecords.removeAll()
            return
        }

        let extraMinionCount = chosenDemons.contains("lordoftyphon") || chosenDemons.contains("lilmonsta") ? 1 : 0
        let chosenMinions = pickUniqueRoleIds(from: minions, count: min(counts.minions + extraMinionCount, minions.count))
        let hasBaron = chosenMinions.contains("baron")
        let hasGodfather = chosenMinions.contains("godfather")
        let hasFangGu = chosenDemons.contains("fang-gu")
        let hasVigormortis = chosenDemons.contains("vigormortis")

        var outsiderShift = hasBaron ? min(2, counts.townsfolk, outsiders.count) : 0
        if hasVigormortis {
            outsiderShift -= 1
        }
        if hasGodfather {
            if counts.outsiders > 0, Bool.random() {
                outsiderShift -= 1
            } else if counts.townsfolk > outsiderShift, counts.outsiders + outsiderShift < outsiders.count {
                outsiderShift += 1
            }
        }
        if hasFangGu, counts.townsfolk > outsiderShift, counts.outsiders + outsiderShift < outsiders.count {
            outsiderShift += 1
        }
        let townsfolkCount = max(0, counts.townsfolk - outsiderShift)
        let outsiderCount = max(0, min(outsiders.count, counts.outsiders + outsiderShift))

        var chosenTowns = pickUniqueRoleIds(from: towns, count: max(0, townsfolkCount - extraMinionCount))
        if chosenTowns.contains("choirboy"),
           !chosenTowns.contains("king"),
           towns.contains(where: { $0.id == "king" }) {
            if let replaceIndex = chosenTowns.firstIndex(where: { $0 != "choirboy" }) {
                chosenTowns[replaceIndex] = "king"
            } else {
                chosenTowns.append("king")
            }
        }
        let hasBalloonist = chosenTowns.contains("balloonist")
        if hasBalloonist, townsfolkCount > 0, outsiderCount < outsiders.count {
            let adjustedTownsfolkCount = max(0, townsfolkCount - 1)
            let adjustedOutsiderCount = min(outsiders.count, outsiderCount + 1)
            var adjustedChosenTowns = pickUniqueRoleIds(from: towns, count: adjustedTownsfolkCount)
            if adjustedChosenTowns.contains("choirboy"),
               !adjustedChosenTowns.contains("king"),
               towns.contains(where: { $0.id == "king" }) {
                if let replaceIndex = adjustedChosenTowns.firstIndex(where: { $0 != "choirboy" }) {
                    adjustedChosenTowns[replaceIndex] = "king"
                } else {
                    adjustedChosenTowns.append("king")
                }
            }
            let adjustedChosenOutsiders = pickUniqueRoleIds(from: outsiders, count: adjustedOutsiderCount)
            var selectedRoles = adjustedChosenTowns + adjustedChosenOutsiders + chosenMinions + chosenDemons
            if selectedRoles.count > playerCount {
                selectedRoles = Array(selectedRoles.shuffled().prefix(playerCount))
            }
            if selectedRoles.count < playerCount {
                let alreadyUsed = Set(selectedRoles)
                let extraRoles = phaseTemplate.roles
                    .map(\.id)
                    .filter { !alreadyUsed.contains($0) }
                    .shuffled()
                let remainingRoles = Array(extraRoles.prefix(playerCount - selectedRoles.count))
                selectedRoles.append(contentsOf: remainingRoles)
            }

            roleDeck = selectedRoles.shuffled().map { RoleDeckCard(roleId: $0, assignedPlayerId: nil, state: .back) }
            gameLog.removeAll()
            nightActionRecords.removeAll()
            return
        }
        let chosenOutsiders = pickUniqueRoleIds(from: outsiders, count: outsiderCount)

        var selectedRoles = chosenTowns + chosenOutsiders + chosenMinions + chosenDemons
        if selectedRoles.count > playerCount {
            selectedRoles = Array(selectedRoles.shuffled().prefix(playerCount))
        }
        if selectedRoles.count < playerCount {
            let alreadyUsed = Set(selectedRoles)
            let extraRoles = phaseTemplate.roles
                .map(\.id)
                .filter { !alreadyUsed.contains($0) }
                .shuffled()
            let remainingRoles = Array(extraRoles.prefix(playerCount - selectedRoles.count))
            selectedRoles.append(contentsOf: remainingRoles)
        }

        roleDeck = selectedRoles.shuffled().map { RoleDeckCard(roleId: $0, assignedPlayerId: nil, state: .back) }
        gameLog.removeAll()
        nightActionRecords.removeAll()
    }

    private func pickUniqueRoleIds(from templates: [RoleTemplate], count: Int, excluding excluded: Set<String> = []) -> [String] {
        let available = templates.map(\.id).filter { !excluded.contains($0) }.shuffled()
        let selectedCount = max(0, min(count, available.count))
        if selectedCount == 0 { return [] }
        return Array(available.prefix(selectedCount))
    }

    var isAssignmentReady: Bool {
        !players.isEmpty && players.allSatisfy { $0.roleId != nil } && roleDeck.allSatisfy { $0.state == .used }
    }

    var assignmentCompletedCount: Int {
        players.filter { $0.roleId != nil }.count
    }

    var assignmentNextSeatLabel: String? {
        guard let nextPlayer = players.first(where: { $0.roleId == nil }) else { return nil }
        return "\(nextPlayer.seatNumber)号位"
    }

    func selectAssignmentPlayer(_ playerId: UUID?) {
        selectedAssignmentPlayerId = playerId
        selectedDeckCardId = nil
    }

    func cardVisualState(_ cardId: UUID) -> RoleDeckDisplayState {
        roleDeck.first(where: { $0.id == cardId })?.state ?? .back
    }

    func assignedPlayer(for cardId: UUID) -> PlayerCard? {
        guard let playerId = roleDeck.first(where: { $0.id == cardId })?.assignedPlayerId else {
            return nil
        }
        return players.first(where: { $0.id == playerId })
    }

    func isRoleRevealedForDashboard(playerId: UUID) -> Bool {
        guard let card = roleDeck.first(where: { $0.assignedPlayerId == playerId }) else {
            return false
        }
        return revealedGrimoireCardIds.contains(card.id)
    }

    func isGrimoireCardRevealed(_ cardId: UUID) -> Bool {
        if !isGrimoireShowingBacks { return true }
        return revealedGrimoireCardIds.contains(cardId)
    }

    func toggleGrimoireCard(_ cardId: UUID) {
        if revealedGrimoireCardIds.contains(cardId) {
            revealedGrimoireCardIds.remove(cardId)
        } else {
            revealedGrimoireCardIds.insert(cardId)
        }
    }

    func clearGrimoireReveals() {
        revealedGrimoireCardIds.removeAll()
    }

    func flipDeckCard(_ cardId: UUID) {
        guard let index = roleDeck.firstIndex(where: { $0.id == cardId }) else { return }
        if let selectedDeckCardId, selectedDeckCardId != cardId {
            return
        }
        var card = roleDeck[index]
        var shouldWriteBack = true
        switch card.state {
        case .back:
            card.state = .front
            selectedDeckCardId = cardId
        case .front:
            if card.roleId == "drunk", card.displayedRoleId == nil {
                roleDeck[index] = card
                return
            }
            let targetPlayerId = players.first(where: { $0.roleId == nil })?.id
            if let targetPlayerId {
                assignRoleCard(cardId, to: targetPlayerId)
                shouldWriteBack = false
            } else {
                card.state = .used
                selectedDeckCardId = nil
            }
        case .used:
            break
        }
        if shouldWriteBack {
            roleDeck[index] = card
        }
    }

    func drawRandomUnassignedCard() -> UUID? {
        roleDeck.first(where: { $0.state == .back || $0.state == .front })?.id
    }

    func assignRandomCard(to playerId: UUID) {
        guard let firstUnused = drawRandomUnassignedCard() else { return }
        assignRoleCard(firstUnused, to: playerId)
    }

    func assignAllRandom() {
        for player in players where player.roleId == nil {
            assignRandomCard(to: player.id)
        }
    }

    private func assignRoleCard(_ cardId: UUID, to playerId: UUID) {
        guard let deckIndex = roleDeck.firstIndex(where: { $0.id == cardId }),
              let playerIndex = players.firstIndex(where: { $0.id == playerId }),
              players[playerIndex].roleId == nil,
              roleDeck[deckIndex].state != .used else {
            return
        }
        let roleId = roleDeck[deckIndex].roleId
        if roleId == "drunk", roleDeck[deckIndex].displayedRoleId == nil {
            return
        }
        let displayedRoleId = roleDeck[deckIndex].displayedRoleId ?? roleId
        roleDeck[deckIndex].state = .used
        roleDeck[deckIndex].assignedPlayerId = playerId
        players[playerIndex].roleId = roleId
        players[playerIndex].originalRoleId = roleId
        players[playerIndex].displayedRoleId = displayedRoleId
        selectedDeckCardId = nil
        selectedAssignmentPlayerId = players.first(where: { $0.roleId == nil })?.id
    }

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

    private func buildNightQueue() {
        updateNoDashiiPoisoning()
        var queue: [NightStepTemplate] = []
        let order = isFirstNightPhase ? phaseTemplate.nightOrderFirst : phaseTemplate.nightOrderStandard
        queue.append(contentsOf: order.filter { step in
            // Keep steps that might activate later in the night (e.g., Ravenkeeper dies mid-night)
            if case .ifActorDiedTonight = step.condition {
                return player(for: step.roleId) != nil
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

    private func shouldKeepNightStep(_ item: NightStepTemplate) -> Bool {
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

    private func diedByDemonTonight(_ player: PlayerCard, actingAs roleId: String) -> Bool {
        guard playerActsAsRole(player, roleId: roleId) else { return false }
        return demonKilledTonight.contains(player.id) || isScheduledForDemonDeathTonight(player.id)
    }

    private func isScheduledForDemonDeathTonight(_ playerId: UUID) -> Bool {
        guard let player = playerLookup(by: playerId), player.alive else {
            return false
        }

        let isPrimaryDemonTarget = pendingNightKill == playerId
        let isForcedDemonTarget = pendingForcedDemonKills.contains(playerId)

        guard isPrimaryDemonTarget || isForcedDemonTarget else {
            return false
        }

        if isPrimaryDemonTarget {
            if hasLeviathanInPlay || princessProtectedNightAfterDay == currentDayNumber || exorcisedPlayerId != nil || demonKillBlockedTonight {
                return false
            }
        }

        if protectedTonight.contains(playerId) || demonProtectedTonight.contains(playerId) {
            return false
        }
        if player.roleId == "soldier", !isAbilitySuppressed(player) {
            return false
        }
        if isProtectedByTeaLady(playerId) {
            return false
        }

        return true
    }

    private func player(for roleId: String) -> PlayerCard? {
        actingPlayer(for: roleId, requireCanWake: true) ??
        actingPlayer(for: roleId)
    }

    func wakeProgressPlayer(for step: NightStepTemplate) -> PlayerCard? {
        player(for: step.roleId)
    }

    private func advanceToCurrentActiveNightStep() {
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

    private enum NightTargetSelectionMode {
        case none
        case alivePlayers(excludingActor: Bool, goodOnly: Bool)
        case allPlayers(excludingActor: Bool)
        case deadPlayers
        case manualOnly
    }

    private func nightTargetSelectionMode(for roleId: String) -> NightTargetSelectionMode {
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

    private func isFlexibleRegistrationPlayer(_ player: PlayerCard) -> Bool {
        player.roleId == "spy" || player.roleId == "recluse"
    }

    private func flexibleRegisteredTeams(for player: PlayerCard) -> Set<RoleTeam> {
        switch player.roleId {
        case "spy":
            return [.townsfolk, .outsider]
        case "recluse":
            return [.minion, .demon]
        default:
            return []
        }
    }

    private func canRegister(_ player: PlayerCard, as team: RoleTeam) -> Bool {
        flexibleRegisteredTeams(for: player).contains(team)
    }

    private func troubleBrewingInfoTeam(for roleId: String) -> RoleTeam? {
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

    private func flexibleRegistrationFallbackPlayer(for team: RoleTeam) -> PlayerCard? {
        players.first { player in
            isFlexibleRegistrationPlayer(player) && canRegister(player, as: team)
        }
    }

    private func troubleBrewingRoleChoiceOption(for role: RoleTemplate, team: RoleTeam) -> NightRoleChoiceOption {
        let roleIsInPlay = players.contains { $0.roleId == role.id }
        let registeringPlayerId = roleIsInPlay ? nil : flexibleRegistrationFallbackPlayer(for: team)?.id
        return NightRoleChoiceOption(
            id: encodedNightRoleChoiceId(roleId: role.id, registeringPlayerId: registeringPlayerId),
            roleId: role.id
        )
    }

    private func sortedRoleOptions(ids: Set<String>) -> [NightRoleChoiceOption] {
        ids
            .compactMap { roleId in roleTemplate(for: roleId) }
            .sorted {
                localizedRoleName($0).localizedStandardCompare(localizedRoleName($1)) == .orderedAscending
            }
            .map { NightRoleChoiceOption(id: $0.id, roleId: $0.id) }
    }

    private func currentNightExactRevealPlayer(for roleId: String) -> PlayerCard? {
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

    private func exactRevealRoleChoiceOptions(for player: PlayerCard) -> [NightRoleChoiceOption] {
        guard let actualRoleId = player.roleId else { return [] }
        var roleIds = Set([actualRoleId])
        for role in phaseTemplate.roles where canRegister(player, as: role.team) {
            roleIds.insert(role.id)
        }
        return sortedRoleOptions(ids: roleIds)
    }

    private func resolvedExactRevealRole(for player: PlayerCard, selectedRoleId: String?) -> RoleTemplate? {
        guard let actualRoleId = player.roleId else { return nil }
        let options = Set(exactRevealRoleChoiceOptions(for: player).compactMap(\.roleId))
        if let selectedRoleId,
           options.contains(selectedRoleId),
           let selectedRole = roleTemplate(for: selectedRoleId) {
            return selectedRole
        }
        return roleTemplate(for: actualRoleId)
    }

    private func shouldUseFullRolePoolForExactReveal(roleId: String) -> Bool {
        guard roleId == "ravenkeeper",
              let actor = currentNightActor else {
            return false
        }
        return isAbilitySuppressed(actor) || isDisplayedDrunk(actor, actingAs: roleId)
    }

    private func shouldUseFullRolePoolForTroubleBrewingInfo(team: RoleTeam) -> Bool {
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

    private func disallowedFlexibleRegistrationRoleIds(for detectorRoleId: String) -> Set<String> {
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
        ui(
            "Choose how \(player.name) registers for this alignment result.",
            "选择 \(player.name) 在本次阵营判定中如何登记。"
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

    private func detectedIsEvil(_ player: PlayerCard) -> Bool {
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
        case "undertaker", "grandmother":
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

    private func nightRoleChoices(for roleId: String) -> [NightRoleChoiceOption] {
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

    private func undertakerExecutionResult(selectedRoleId: String? = nil) -> (player: PlayerCard, role: RoleTemplate)? {
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

    private func doesPlayerWakeTonightDueToOwnAbility(_ player: PlayerCard) -> Bool {
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

    private func countWakingPlayers(for targetIds: [UUID]) -> Int {
        targetIds.compactMap { playerLookup(by: $0) }
            .filter { doesPlayerWakeTonightDueToOwnAbility($0) }
            .count
    }

    private func handleGrandmotherAction(actor: PlayerCard, targets: [UUID], shownRoleId: String) {
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

    private func handleSailorAction(actor: PlayerCard, targets: [UUID]) {
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

    private func handleChambermaidAction(actor: PlayerCard, targets: [UUID]) {
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

    private func handleInnkeeperAction(actor: PlayerCard, targets: [UUID]) {
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

    private func handleGamblerAction(actor: PlayerCard, targets: [UUID], note: String) {
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

    private func handleCourtierAction(actor: PlayerCard, note: String) {
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

    private func handleLunaticAction(actor: PlayerCard, targets: [UUID], note: String) {
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

    private func revealRandomGoodPlayer(excluding excluded: Set<UUID> = []) -> PlayerCard? {
        players
            .filter { $0.alive && !excluded.contains($0.id) && isPlayerGood($0) }
            .randomElement()
    }

    private func revealRandomAliveCharacter(excluding excluded: Set<UUID> = []) -> RoleTemplate? {
        players
            .filter { $0.alive && !excluded.contains($0.id) }
            .compactMap { roleTemplate(for: $0.roleId ?? "") }
            .randomElement()
    }

    private func orderedSeatedPlayers() -> [PlayerCard] {
        players.sorted { $0.seatNumber < $1.seatNumber }
    }

    private func aliveNeighbors(of player: PlayerCard) -> [PlayerCard] {
        let living = orderedSeatedPlayers().filter(\.alive)
        guard living.count >= 2,
              let index = living.firstIndex(where: { $0.id == player.id }) else {
            return []
        }
        let left = living[(index - 1 + living.count) % living.count]
        let right = living[(index + 1) % living.count]
        return [left, right]
    }

    private func reviveIfDead(_ playerId: UUID, reason: String) {
        guard let index = players.firstIndex(where: { $0.id == playerId }), !players[index].alive else { return }
        players[index].alive = true
        players[index].deadReason = nil
        players[index].isDeadTonight = false
        players[index].roleLog.append(ui("Returned to life: \(reason)", "复活：\(reason)"))
        addLog("\(players[index].name) returned to life.", "\(players[index].name) 复活。")
    }

    private func handleStewardAction(actor: PlayerCard) {
        guard let known = revealRandomGoodPlayer(excluding: [actor.id]) else {
            appendActionLog("\(actor.name) had no valid Steward result.", "\(actor.name) 没有有效的总管结果。")
            return
        }
        appendActionLog("\(actor.name) learned that \(known.name) is good.", "\(actor.name) 得知 \(known.name) 是善良玩家。")
        markPlayer(actor.id) { player in
            player.roleLog.append(ui("Learned that \(known.name) is good.", "得知 \(known.name) 是善良玩家。"))
        }
    }

    private func handleNobleAction(actor: PlayerCard, targets: [UUID]) {
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

    private func handleKnightAction(actor: PlayerCard) {
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

    private func handleShugenjaAction(actor: PlayerCard) {
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

    private func handlePixieAction(actor: PlayerCard, note: String) {
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

    private func handleHighPriestessAction(actor: PlayerCard) {
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

    private func handleKingAction(actor: PlayerCard) {
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

    private func handleChoirboyAction(actor: PlayerCard) {
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

    private func handleAcrobatAction(actor: PlayerCard, targets: [UUID]) {
        guard let target = targets.first, let targetPlayer = playerLookup(by: target) else {
            appendActionLog("\(actor.name) woke as Acrobat but chose no player.", "\(actor.name) 作为杂技演员醒来，但没有选择玩家。")
            return
        }
        acrobatTrackedPlayerIds[actor.id] = targetPlayer.id
        appendActionLog("\(actor.name) is watching \(targetPlayer.name) for poison or drunkenness.", "\(actor.name) 正在观察 \(targetPlayer.name) 是否中毒或醉酒。")
    }

    private func handleFearmongerAction(actor: PlayerCard, targets: [UUID]) {
        guard let target = targets.first, let targetPlayer = playerLookup(by: target) else {
            appendActionLog("\(actor.name) woke as Fearmonger but chose no target.", "\(actor.name) 作为恐惧贩子醒来，但没有选择目标。")
            return
        }
        fearmongerTargetByPlayerId[actor.id] = targetPlayer.id
        appendActionLog("\(actor.name) chose \(targetPlayer.name) as the Fearmonger target.", "\(actor.name) 选择 \(targetPlayer.name) 作为恐惧贩子的目标。")
    }

    private func handleHarpyAction(actor: PlayerCard, targets: [UUID]) {
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

    private func handleAlchemistAction(actor: PlayerCard, note: String) {
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

    private func handleBoffinAction(actor: PlayerCard, note: String) {
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

    private func handleMezephelesAction(actor: PlayerCard, note: String) {
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            appendActionLog("\(actor.name) needs a secret word for Mezepheles.", "\(actor.name) 需要为梅泽菲勒斯输入秘密单词。")
            return
        }
        appendActionLog("\(actor.name) set the Mezepheles word: \(trimmed).", "\(actor.name) 设定了梅泽菲勒斯单词：\(trimmed)。")
    }

    private func handleAlHadikhiaAction(actor: PlayerCard, targets: [UUID], note: String) {
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

    private func handleOjoAction(actor: PlayerCard, note: String) {
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

    private func handleYaggababbleAction(actor: PlayerCard, note: String) {
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

    private func handleCultLeaderNight(actor: PlayerCard) {
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

    private func handleEngineerChange(note: String, actor: PlayerCard) {
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

    private func handleSummonerAction(actor: PlayerCard, targets: [UUID], note: String) {
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
                text: currentLogLine(for: actor, roleId: roleId, targetText: recordTargetText, note: recordNote)
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
                appendRoleRecord(for: actor.id, text: ui("\(actor.name) skipped \(localizedRoleName(roleTemplate(for: roleId))) because of poison.", "\(actor.name) 因中毒跳过了 \(localizedRoleName(roleTemplate(for: roleId)))。"))
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
                pendingForcedNightKills.append(target)
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
                pendingNightKill = target
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
                pendingNightKill = target
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
                pendingForcedDemonKills.append(target)
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
                pendingForcedDemonKills.append(target)
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
                    pendingNightKill = target
                    appendActionLog("\(actor.name) chose a Fang Gu kill target: \(targetText).", "\(actor.name) 选择了方固夜杀目标：\(targetText)。")
                }
            }
        case "vigormortis":
            if let target = targets.first {
                pendingNightKill = target
                appendActionLog("\(actor.name) chose a Vigormortis kill target: \(targetText).", "\(actor.name) 选择了维戈莫提斯夜杀目标：\(targetText)。")
            }
        case "no-dashii":
            if let target = targets.first {
                pendingNightKill = target
                appendActionLog("\(actor.name) chose a No Dashii kill target: \(targetText).", "\(actor.name) 选择了诺达希夜杀目标：\(targetText)。")
            }
        case "lordoftyphon":
            if let target = targets.first {
                pendingNightKill = target
                appendActionLog("\(actor.name) chose a Lord of Typhon kill target: \(targetText).", "\(actor.name) 选择了提丰之主夜杀目标：\(targetText)。")
            }
        case "ojo":
            handleOjoAction(actor: actor, note: note)
        case "yaggababble":
            handleYaggababbleAction(actor: actor, note: note)
        case "zombuul":
            if !didDeathOccurToday, let target = targets.first {
                pendingNightKill = target
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
                pendingNightKill = target
                appendActionLog("\(actor.name) chose a Vortox kill target: \(targetText).", "\(actor.name) 选择了沃托克斯夜杀目标：\(targetText)。")
            }
        default:
            let roleName = localizedRoleName(roleTemplate(for: roleId))
            appendActionLog("\(roleName) action completed.", "\(roleName) 的行动已完成。")
        }

        appendRoleRecord(
            for: actor.id,
            text: currentLogLine(for: actor, roleId: roleId, targetText: recordTargetText, note: recordNote)
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

    private func proceedToNextNightStep() {
        currentNightTargets.removeAll()
        currentNightNote = ""
        currentNightAlignmentSelections.removeAll()
        currentNightStepIndex += 1
        advanceToCurrentActiveNightStep()
    }

    private func resolveNightDawn() {
        if hasLeviathanInPlay {
            addLog("Leviathan is in play. No Demon kill occurs tonight.", "利维坦在场，今夜不会发生恶魔击杀。")
        } else if princessProtectedNightAfterDay == currentDayNumber {
            addLog("Princess prevented the Demon from killing tonight.", "公主阻止了恶魔今夜杀人。")
        } else if let exorcisedPlayerId,
                  let exorcisedPlayer = players.first(where: { $0.id == exorcisedPlayerId }) {
            addLog("The Exorcist prevented \(exorcisedPlayer.name) from waking tonight.", "驱魔人阻止了 \(exorcisedPlayer.name) 今夜醒来。")
        } else if demonKillBlockedTonight, let target = pendingNightKill, let targetPlayer = players.first(where: { $0.id == target }) {
            addLog("The Demon's kill on \(targetPlayer.name) was blocked by the Lycanthrope.", "\(targetPlayer.name) 受到狼人的影响，恶魔今夜未能击杀。")
        } else if demonKillBlockedTonight {
            addLog("The Demon did not kill tonight because of the Lycanthrope.", "由于狼人的效果，恶魔今夜没有击杀。")
        } else if let target = pendingNightKill, let targetPlayer = players.first(where: { $0.id == target }) {
            if protectedTonight.contains(target) || demonProtectedTonight.contains(target) {
                addLog("Night kill on \(targetPlayer.name) was prevented by night protection.", "\(targetPlayer.name) 的夜杀被夜间保护抵消了。")
            } else if targetPlayer.roleId == "soldier", !isAbilitySuppressed(targetPlayer) {
                addLog("Night kill on \(targetPlayer.name) was blocked by Soldier.", "\(targetPlayer.name) 的夜杀被士兵能力抵消了。")
            } else if targetPlayer.alive {
                killByDemonIfAlive(target, reason: ui("Killed by night action", "夜间技能击杀"))
                if players.contains(where: { $0.alive && $0.roleId == "vigormortis" }) {
                    applyVigormortisAfterKill(target)
                }
            } else {
                addLog("Night kill on \(targetPlayer.name) had no effect.", "对 \(targetPlayer.name) 的夜杀没有产生效果。")
            }
        } else if !gossipKillTonight && moonchildPendingTargetId == nil {
            addLog("No night kill was selected.", "本夜没有选择夜杀目标。")
        }

        for target in pendingForcedNightKills {
            if let targetPlayer = playerLookup(by: target), targetPlayer.alive {
                if protectedTonight.contains(target) {
                    addLog("Night kill on \(targetPlayer.name) was prevented by night protection.", "\(targetPlayer.name) 的夜杀被夜间保护抵消了。")
                } else {
                    killIfAlive(target, reason: ui("Killed by night action", "夜间技能击杀"))
                }
            }
        }

        for target in pendingForcedDemonKills {
            if let targetPlayer = playerLookup(by: target), targetPlayer.alive {
                if protectedTonight.contains(target) || demonProtectedTonight.contains(target) {
                    addLog("Night kill on \(targetPlayer.name) was prevented by night protection.", "\(targetPlayer.name) 的夜杀被夜间保护抵消了。")
                } else if targetPlayer.roleId == "soldier", !isAbilitySuppressed(targetPlayer) {
                    addLog("Night kill on \(targetPlayer.name) was blocked by Soldier.", "\(targetPlayer.name) 的夜杀被士兵能力抵消了。")
                } else {
                    killByDemonIfAlive(target, reason: ui("Killed by night action", "夜间技能击杀"))
                }
            }
        }

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
        pendingNightKill = nil
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

    private func clearNightAfterDawn() {
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

    private func resolveGossipKillIfNeeded() {
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

    private func resolveMoonchildKillIfNeeded() {
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

    private func resolveAcrobatDeathsIfNeeded() {
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

    private func resolveChoirboyInfoIfNeeded() {
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

    private func resolveCultLeaderAlignmentAtDawn() {
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

    private func resolveXaanPoisoningIfNeeded() {
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

    private func applyVigormortisAfterKill(_ targetId: UUID) {
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

    private func handleDayStartEffects() {
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

    private func updateNoDashiiPoisoning() {
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

    private func prepareImpReplacementSelection() {
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

    private func resolveNominationStart(nominatorId: UUID, nomineeId: UUID) {
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

    private func resolveRiotNomination(_ nomineeId: UUID) {
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

    private func executeSlayerShot(recluseRegisterAsDemon: Bool) {
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

    // MARK: - Helpers

    private func expireDuskLimitedEffects() {
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

    private func setTemporaryDrunk(playerId: UUID, untilDayNumber: Int, source: String) {
        temporaryDrunkPlayerUntilDayNumbers[playerId] = untilDayNumber
        temporaryDrunkPlayerSources[playerId] = source
    }

    private func setTemporaryDrunk(roleId: String, untilDayNumber: Int, source: String) {
        temporaryDrunkRoleUntilDayNumbers[roleId] = untilDayNumber
        temporaryDrunkRoleSources[roleId] = source
    }

    private func preferredNamedTargetId(from note: String, actor: PlayerCard, availableTargetIds: [UUID]) -> UUID? {
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

    private func killByDemonIfAlive(_ playerId: UUID, reason: String) {
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

    private func activateBanshee(_ playerId: UUID) {
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

    private func resolveFarmerDeathIfNeeded(_ deadPlayer: PlayerCard) {
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

    private func resolveGrandmotherDeathIfNeeded(grandchildId: UUID) {
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

    private func setPoisoned(_ playerID: UUID, _ poisoned: Bool) {
        markPlayer(playerID) { p in
            p.poisonedTonight = poisoned
            if poisoned { p.roleLog.append(ui("Poisoned tonight.", "今夜中毒。")) }
        }
    }

    private func setProtected(_ playerID: UUID, _ protected: Bool, source: String) {
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

    private func setButlerMaster(_ actorID: UUID, master: UUID) {
        markPlayer(actorID) { p in
            p.butlerMasterId = master
            p.wasButlerTonight = true
        }
        markPlayer(master) { p in
            p.roleLog.append(ui("Was chosen as the Butler's master.", "被选为管家的主人。"))
        }
    }

    private func applyVoteModifier(_ playerID: UUID, delta: Int) {
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

    private func isAbilitySuppressed(_ player: PlayerCard) -> Bool {
        if playerIsPoisonedOrDrunk(player) {
            return true
        }
        if isSuppressedByPreacher(player) {
            return true
        }
        return false
    }

    func isPlayerPoisonedOrDrunk(_ player: PlayerCard) -> Bool {
        playerIsPoisonedOrDrunk(player)
    }

    func isPlayerExternallyPoisonedOrDrunk(_ player: PlayerCard) -> Bool {
        playerIsPoisoned(player) || playerIsExternallyDrunk(player)
    }

    private func playerIsPoisonedOrDrunk(_ player: PlayerCard) -> Bool {
        if player.roleId == "drunk" { return true }
        if playerIsPoisoned(player) { return true }
        if playerIsExternallyDrunk(player) { return true }
        return false
    }

    private func playerIsPoisoned(_ player: PlayerCard) -> Bool {
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

    private func poisonerPoisonIsActive(on player: PlayerCard) -> Bool {
        guard let poisonerPoisonedPlayerId,
              poisonerPoisonedPlayerId == player.id else {
            return false
        }
        if let poisonerPoisonSourcePlayerId {
            return players.contains { $0.id == poisonerPoisonSourcePlayerId && $0.alive }
        }
        return players.contains { $0.alive && $0.roleId == "poisoner" }
    }

    private func playerIsExternallyDrunk(_ player: PlayerCard) -> Bool {
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

    private func canWakeAtNight(_ player: PlayerCard) -> Bool {
        player.alive || vigormortisEmpoweredMinionIds.contains(player.id)
    }

    private func isProtectedByTeaLady(_ playerId: UUID) -> Bool {
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

    private func shouldPacifistSave(_ player: PlayerCard, reason: String) -> Bool {
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

    private func killIfAlive(_ playerId: UUID, reason: String) {
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

    private func resolveDaytimeDemonDeath(deadRoleId: String?, aliveCountBeforeDeath: Int, reason: String) {
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

    private func clearNightState() {
        pendingNightKill = nil
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
        pendingForcedNightKills.removeAll()
        pendingForcedDemonKills.removeAll()
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

    private func clearDayState() {
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

    private func appendRoleRecord(for playerID: UUID, text: String) {
        markPlayer(playerID) { $0.roleLog.append(text) }
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

    private func appendActionLog(_ text: String) {
        addLog(text, toneOverride: currentActionLogToneOverride)
    }

    private func appendActionLog(_ english: String, _ chinese: String) {
        addLog(english, chinese, toneOverride: currentActionLogToneOverride)
    }

    private func appendNightActionRecord(actor: UUID, roleId: String, targets: [UUID], note: String) {
        nightActionRecords.append(NightActionRecord(roleId: roleId, actorPlayerId: actor, selectedTargets: targets, note: note))
    }

    private func handleTroubleBrewingFirstNightInfo(actor: PlayerCard, roleId: String, targets: [UUID], note: String) {
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

    private func currentLogLine(for actor: PlayerCard, roleId: String, targetText: String, note: String) -> String {
        let actionKey = roleActionKey(for: actor, roleId: roleId, targetText: targetText, note: note)
        let safeTargetText = targetText.replacingOccurrences(of: "|", with: "/")
        let safeNote = note.replacingOccurrences(of: "|", with: "/")
        return "\(roleActionRecordPrefix)\(actionKey)|\(actor.name)|\(safeTargetText)|\(safeNote)"
    }

    private func roleActionKey(for actor: PlayerCard, roleId: String, targetText: String, note: String) -> String {
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

    func roleTemplate(for id: String) -> RoleTemplate? {
        scriptCatalog.roleTemplate(
            for: id,
            templateId: selectedTemplateId,
            includingExperimental: experimentalEditionIds.contains(selectedTemplateId)
        )
    }

    private var isVirginExecuting: Bool = false

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

    private func isButlerVoteAllowed(voter: PlayerCard, nominee: UUID?) -> Bool {
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

    private func maybeProcessVirginNomination(_ nomineeId: UUID?, nominatorRegistersAsTownsfolk: Bool? = nil) {
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

    private func needsVirginRegistrationChoice(for nomineeId: UUID?, nominatorId: UUID?) -> Bool {
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

    private func markPlayer(_ playerID: UUID, _ updater: (inout PlayerCard) -> Void) {
        guard let index = players.firstIndex(where: { $0.id == playerID }) else { return }
        updater(&players[index])
    }

    private func playerLookup(by id: UUID) -> PlayerCard? {
        players.first(where: { $0.id == id })
    }

    private func playerName(_ playerId: UUID) -> String? {
        players.first(where: { $0.id == playerId })?.name
    }

    private func parseRoleId(from note: String) -> String? {
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let normalized = trimmed.lowercased()
        return phaseTemplate.roles.first {
            $0.id.lowercased() == normalized ||
            $0.name.lowercased() == normalized ||
            $0.chineseName == trimmed
        }?.id
    }

    private func prepareFirstNightExperimentalState() {
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

    private func assignBountyHunterEvilPlayer() {
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

    private func assignEvilTwinPair() {
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

    private func shouldWakeBountyHunterTonight() -> Bool {
        guard let knownId = bountyHunterKnownPlayerId else { return true }
        return players.contains(where: { $0.id == knownId && !$0.alive })
    }

    private func bountyHunterRevealPlayer() -> PlayerCard? {
        let evilPlayers = players.filter { isPlayerEvil($0) }
        let preferred = evilPlayers.filter { !bountyHunterKnownHistory.contains($0.id) }
        let pool = preferred.isEmpty ? evilPlayers : preferred
        guard let chosen = pool.randomElement() else { return nil }
        bountyHunterKnownPlayerId = chosen.id
        bountyHunterKnownHistory.insert(chosen.id)
        return chosen
    }

    private func balloonistRevealPlayer(suppressed: Bool) -> PlayerCard? {
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

    private func generalAlignmentResult() -> (english: String, chinese: String) {
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

    private func assignVillageIdiotDrunkPlayer() {
        let villageIdiots = players.filter { $0.roleId == "villageidiot" }
        guard villageIdiots.count > 1 else {
            villageIdiotDrunkPlayerId = nil
            return
        }
        villageIdiotDrunkPlayerId = villageIdiots.randomElement()?.id
    }

    private func villageIdiotResult(for target: PlayerCard) -> (english: String, chinese: String) {
        let actualIsEvil = detectedIsEvil(target)
        let isDrunkVillageIdiot = currentNightActor?.id == villageIdiotDrunkPlayerId
        let shownIsEvil = isDrunkVillageIdiot ? !actualIsEvil : actualIsEvil
        return shownIsEvil ? ("evil", "邪恶") : ("good", "善良")
    }

    private func isPlayerEvil(_ player: PlayerCard) -> Bool {
        if let override = alignmentOverrides[player.id] {
            return override
        }
        if bountyHunterEvilPlayerId == player.id {
            return true
        }
        guard let role = roleTemplate(for: player.roleId ?? "") else { return false }
        return role.team == .minion || role.team == .demon
    }

    private func isPlayerGood(_ player: PlayerCard) -> Bool {
        !isPlayerEvil(player)
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

    func toggleGrimoire() {
        isGrimoireShowingBacks.toggle()
        if isGrimoireShowingBacks {
            clearGrimoireReveals()
        } else {
            revealedGrimoireCardIds = Set(roleDeck.map(\.id))
        }
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

    private func gameOverCheck() {
        guard phase != .finished else { return }
        let alivePlayers = players.filter(\.alive)
        if alivePlayers.isEmpty { return }

        let bothTwinsAlive =
            evilTwinPlayerId != nil &&
            evilTwinGoodPlayerId != nil &&
            alivePlayers.contains(where: { $0.id == evilTwinPlayerId }) &&
            alivePlayers.contains(where: { $0.id == evilTwinGoodPlayerId })

        let aliveGoodCount = alivePlayers.filter { isPlayerGood($0) }.count
        let aliveEvilCount = alivePlayers.filter { isPlayerEvil($0) }.count
        let aliveDemonCount = alivePlayers.filter {
            $0.alive && roleTemplate(for: $0.roleId ?? "")?.team == .demon
        }.count

        if bothTwinsAlive && aliveDemonCount == 0 {
            return
        }

        if aliveDemonCount == 0 {
            setGameOver(reason: .noDemonsAlive, side: .good)
            return
        }

        if aliveEvilCount >= aliveGoodCount && !alivePlayers.isEmpty {
            setGameOver(reason: .evilPopulationLead, side: .evil)
            return
        }

        if !evilHasPossibleWinningPath(alivePlayers: alivePlayers) {
            setGameOver(reason: .evilNoWinningPath, side: .good)
            return
        }
    }

    private func evilHasPossibleWinningPath(alivePlayers: [PlayerCard]) -> Bool {
        let aliveGoodCount = alivePlayers.filter { isPlayerGood($0) }.count
        let aliveEvilCount = alivePlayers.filter { isPlayerEvil($0) }.count

        guard aliveEvilCount > 0 else { return false }
        guard aliveGoodCount > 0 else { return true }

        if aliveEvilCount >= aliveGoodCount {
            return true
        }

        let hasAliveDemon = alivePlayers.contains {
            roleTemplate(for: $0.roleId ?? "")?.team == .demon
        }
        let canWinByNight = hasAliveDemon && aliveGoodCount > 0
        let canWinByVote = aliveGoodCount > 1
        return canWinByNight || canWinByVote
    }

    private func addLog(_ text: String, toneOverride: LogTone? = nil) {
        gameLog.insert(
            GameEvent(timestamp: Date(), phase: phase.rawValue, englishText: text, chineseText: text, toneOverride: toneOverride),
            at: 0
        )
    }

    private func addLog(_ english: String, _ chinese: String, toneOverride: LogTone? = nil) {
        gameLog.insert(
            GameEvent(timestamp: Date(), phase: phase.rawValue, englishText: english, chineseText: chinese, toneOverride: toneOverride),
            at: 0
        )
    }

    private func setGameOver(reason: GameOverReason, side: WinningSide) {
        winningSide = side
        gameOverReason = reason
        isGameOver = true
        phase = .finished
        stopTimer()
        if let pair = gameOverMessagePair {
            addLog(pair.english, pair.chinese)
        }
    }
}

private extension String {
    func capture(prefix: String, suffix: String) -> String? {
        guard hasPrefix(prefix) else { return nil }
        let remainder = String(dropFirst(prefix.count))
        if suffix.isEmpty {
            return remainder
        }
        guard remainder.hasSuffix(suffix) else { return nil }
        return String(remainder.dropLast(suffix.count))
    }

    func captureTwo(before separator: String, after suffix: String) -> (String, String)? {
        guard let range = range(of: separator) else { return nil }
        let left = String(self[..<range.lowerBound])
        let right = String(self[range.upperBound...])
        if suffix.isEmpty {
            return (left, right)
        }
        guard right.hasSuffix(suffix) else { return nil }
        return (left, String(right.dropLast(suffix.count)))
    }
}

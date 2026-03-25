import Foundation

enum RoleTeam: String, CaseIterable, Codable {
    case townsfolk
    case outsider
    case minion
    case demon
    case traveller
}

enum PhaseType: String, Codable {
    case templateSelection
    case playerSetup
    case assignment
    case impBluffs
    case impBluffsReveal
    case firstNight
    case day
    case night
    case finished
}

enum AppLanguage: String, CaseIterable, Codable, Identifiable {
    case english
    case chinese

    var id: String { rawValue }

    var shortLabel: String {
        switch self {
        case .english:
            "EN"
        case .chinese:
            "中文"
        }
    }
}

enum WinningSide: String, Codable {
    case good
    case evil
}

enum GameOverReason: String, Codable {
    case mayorSurvived
    case saintExecuted
    case noDemonsAlive
    case evilPopulationLead
    case evilNoWinningPath
}

enum LogTone {
    case primary
    case transfer
    case poison
    case drunk
    case noAction
    case kill
}

enum LogToneClassifier {
    private static let transferKeywords = [
        "became the ",
        "became the new ",
        "became riot",
        "become riot",
        "replacement selected after the ",
        "transformed ",
        "turn into ",
        "turned into ",
        "转变为",
        "转变为了",
        "成为了新的",
        "成为了农夫",
        "被选为替代",
        "变形了",
        " 变为 "
    ]

    private static let poisonEnglishPatterns = [
        #"\bpoisoned\b(?! player)"#,
        #"\bbecause of poison\b"#,
        #"\bpoison target\b"#,
        #"\bpoisoning their townsfolk neighbors\b"#
    ]

    private static let poisonChinesePatterns = [
        #"施加了中毒"#,
        #"因中毒"#,
        #"中毒[。！!，,、；;：:—\-]"#,
        #"投毒目标"#,
        #"被[^。！!，,、；;：:\s]*投毒"#,
        #"以普卡之力毒了"#,
        #"醉酒或中毒而"#,
        #"使所有镇民中毒直到黄昏"#,
        #"毒化其相邻镇民"#,
        #"已中毒，没有产生效果"#
    ]

    private static let drunkKeywords = [
        "drunk", "醉酒", "致醉", "酒鬼"
    ]

    private static let noActionKeywords = [
        "no execution", "没有处决", "无人被处决",
        "no night kill", "没有选择夜杀",
        "did not kill", "没有击杀",
        "chose no", "chose not to", "没有选择", "未选择",
        "but no target", "无目标",
        "no real effect", "没有真实效果",
        "had no effect", "没有产生效果",
        "prevented by", "抵消",
        "blocked by",
        "prevented the demon from killing", "阻止了恶魔今夜杀人",
        "skipped", "跳过",
        "but it failed", "但失败了",
        "unsuccessfully", "但未成功",
        "no nomination reached", "没有提名达到"
    ]

    private static let killKeywords = [
        "died", "killed", " kill", "execution:", "was executed",
        "死亡", "杀死", "处决", "击杀", "被处决", "夜杀"
    ]

    static func classify(englishText: String, chineseText: String) -> LogTone {
        let combined = "\(englishText)\n\(chineseText)".lowercased()

        if containsAny(in: combined, keywords: transferKeywords) {
            return .transfer
        }
        if containsAny(in: combined, keywords: drunkKeywords) {
            return .drunk
        }
        if matchesAnyRegex(in: combined, patterns: poisonEnglishPatterns)
            || matchesAnyRegex(in: chineseText, patterns: poisonChinesePatterns) {
            return .poison
        }
        if containsAny(in: combined, keywords: noActionKeywords) {
            return .noAction
        }
        if containsAny(in: combined, keywords: killKeywords) {
            return .kill
        }
        return .primary
    }

    static func classify(text: String) -> LogTone {
        classify(englishText: text, chineseText: text)
    }

    private static func containsAny(in source: String, keywords: [String]) -> Bool {
        keywords.contains { source.contains($0) }
    }

    private static func matchesAnyRegex(in source: String, patterns: [String]) -> Bool {
        patterns.contains { source.range(of: $0, options: .regularExpression) != nil }
    }
}

enum TimerPreset: Int, CaseIterable, Identifiable, Codable {
    case minute = 60
    case twoMinutes = 120
    case threeMinutes = 180
    case fiveMinutes = 300

    var id: Int { rawValue }
    var label: String { "\(rawValue)s" }
}

enum RoleDeckDisplayState: String, CaseIterable, Codable {
    case back
    case front
    case used
}

enum NightStepCondition: Equatable, Hashable {
    case always
    case ifRoleInPlay(roleId: String)
    case ifExecutionHappenedToday
    case ifActorDiedTonight(roleId: String)
}

struct RoleTemplate: Identifiable, Hashable {
    let id: String
    let name: String
    let chineseName: String
    let team: RoleTeam
    let summary: String
    var chineseSummary: String = ""
    let detail: String
    var chineseDetail: String = ""
    var icon: String = ""
    let firstNight: Bool
    let otherNights: Bool
    let otherNightsExceptFirst: Bool
    let targetCountFirstNight: Int
    let targetCountNight: Int
    let needsNightResultInput: Bool

    var phaseTag: String {
        if firstNight && otherNights {
            "both"
        } else if firstNight {
            "first night"
        } else {
            "other nights"
        }
    }
}

struct ScriptTemplate: Identifiable {
    let id: String
    let name: String
    let chineseName: String
    let roles: [RoleTemplate]
    let nightOrderFirst: [NightStepTemplate]
    let nightOrderStandard: [NightStepTemplate]

    func countTarget(for playerCount: Int) -> (townsfolk: Int, outsiders: Int, minions: Int, demons: Int) {
        let count = max(5, min(20, playerCount))
        switch count {
        case 5:
            return (3, 0, 1, 1)
        case 6:
            return (3, 1, 1, 1)
        case 7:
            return (5, 0, 1, 1)
        case 8:
            return (5, 1, 1, 1)
        case 9:
            return (5, 2, 1, 1)
        case 10:
            return (7, 0, 2, 1)
        case 11:
            return (7, 1, 2, 1)
        case 12:
            return (7, 2, 2, 1)
        case 13:
            return (9, 0, 3, 1)
        case 14:
            return (9, 1, 3, 1)
        default:
            return (9, 2, 3, 1)
        }
    }
}

struct NightStepTemplate: Identifiable, Hashable {
    let id: String
    let roleId: String
    let condition: NightStepCondition
}

struct NightRoleChoiceOption: Identifiable, Hashable {
    let id: String
    let roleId: String?
}

struct PlayerCard: Identifiable, Codable, Hashable {
    let id: UUID
    var seatNumber: Int
    var name: String
    var roleId: String?
    var originalRoleId: String?
    var displayedRoleId: String?
    var alive: Bool
    var deadReason: String?
    var voteModifier: Int
    var butlerMasterId: UUID?
    var poisonedTonight: Bool
    var protectedTonight: Bool
    var becameDemonTonight: Bool
    var wasButlerTonight: Bool
    var wasNominated: Bool
    var slayerShotUsed: Bool
    var ghostVoteAvailable: Bool
    var roleLog: [String]
    var isDeadTonight: Bool
}

struct GameEvent: Identifiable, Hashable {
    let id = UUID()
    let timestamp: Date
    let phase: String
    let englishText: String
    let chineseText: String
    var toneOverride: LogTone?

    var logTone: LogTone {
        toneOverride ?? LogToneClassifier.classify(
            englishText: englishText,
            chineseText: chineseText
        )
    }

    var isKillOrExecution: Bool {
        let killKeywords = ["died", "killed", " kill", "Execution:", "was executed",
                            "死亡", "杀死", "处决", "击杀", "被处决", "夜杀"]
        let text = englishText + chineseText
        return killKeywords.contains { text.contains($0) }
    }

    var isNoAction: Bool {
        let noActionKeywords = [
            "No execution", "no execution", "没有处决", "无人被处决",
            "No night kill", "没有选择夜杀",
            "did not kill", "没有击杀",
            "chose no", "chose not to",
            "没有选择", "未选择",
            "but no target", "无目标",
            "no real effect", "没有真实效果",
            "skipped", "跳过",
            "but it failed", "但失败了",
            "unsuccessfully", "但未成功",
            "No nomination reached", "没有提名达到"
        ]
        let text = englishText + chineseText
        return noActionKeywords.contains { text.contains($0) }
    }

    var isPoisonAction: Bool {
        logTone == .poison
    }
}

struct NightActionRecord: Identifiable {
    let id = UUID()
    let roleId: String
    let actorPlayerId: UUID?
    let selectedTargets: [UUID]
    let note: String
}

struct RoleDeckCard: Identifiable, Codable, Hashable {
    let id: UUID
    let roleId: String
    var assignedPlayerId: UUID?
    var displayedRoleId: String?
    var state: RoleDeckDisplayState

    init(
        id: UUID = UUID(),
        roleId: String,
        assignedPlayerId: UUID?,
        displayedRoleId: String? = nil,
        state: RoleDeckDisplayState
    ) {
        self.id = id
        self.roleId = roleId
        self.assignedPlayerId = assignedPlayerId
        self.displayedRoleId = displayedRoleId
        self.state = state
    }
}

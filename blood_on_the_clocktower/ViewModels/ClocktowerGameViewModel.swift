import Foundation
import Combine
import SwiftUI

final class ClocktowerGameViewModel: ObservableObject {
    static let roleActionRecordPrefix = "[[role-action]]|"

    let roleActionRecordPrefix = ClocktowerGameViewModel.roleActionRecordPrefix
    let recordedLogTonePrefix = "[[log-tone]]|"
    let noOutsiderChoiceID = "__no_outsider__"
    let nightRoleChoiceRegistrationSeparator = "::registered-by::"

    @Published var templates: [ScriptTemplate]
    let scriptCatalog: ScriptCatalog
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

    var timer: Timer?
    var demonProtectedTonight: Set<UUID> = []
    var protectedTonight: Set<UUID> = []
    var deadTonight: Set<UUID> = []
    var demonKilledTonight: Set<UUID> = []
    var impDiedTonight: Bool = false
    var demonKillBlockedTonight: Bool = false
    var exorcisedPlayerId: UUID?
    var widowPoisonedPlayerId: UUID?
    var widowKnownPlayerId: UUID?
    var lleechHostPlayerId: UUID?
    var grandmotherLinkedPlayerIds: [UUID: UUID] = [:]
    var fortuneTellerRedHerringId: UUID?
    var bountyHunterEvilPlayerId: UUID?
    var bountyHunterKnownPlayerId: UUID?
    var bountyHunterKnownHistory: Set<UUID> = []
    var balloonistLastShownType: RoleTeam?
    var nightwatchmanUsedPlayerIds: Set<UUID> = []
    var preachedMinionIds: Set<UUID> = []
    var villageIdiotDrunkPlayerId: UUID?
    var acrobatTrackedPlayerIds: [UUID: UUID] = [:]
    var fearmongerTargetByPlayerId: [UUID: UUID] = [:]
    var harpyMadPlayerId: UUID?
    var harpyAccusedPlayerId: UUID?
    var bansheeEmpoweredPlayerIds: Set<UUID> = []
    var bansheeNominationsUsedByDay: [UUID: Int] = [:]
    var kingKilledByDemonPlayerId: UUID?
    var pixieLearnedRoleByPlayerId: [UUID: String] = [:]
    var alchemistGrantedAbilityRoleId: String?
    var boffinGrantedAbilityRoleId: String?
    var xaanNightNumber: Int?
    var xaanPoisonedUntilDayNumber: Int?
    var princessProtectedNightAfterDay: Int?
    var leviathanGoodExecutions: Int = 0
    var riotActivated: Bool = false
    var foolSpentPlayerIds: Set<UUID> = []
    var devilsAdvocateProtectedPlayerId: UUID?
    var outsiderExecutedToday: Bool = false
    var assassinUsedPlayerIds: Set<UUID> = []
    var professorUsedPlayerIds: Set<UUID> = []
    var courtierUsedPlayerIds: Set<UUID> = []
    var huntsmanUsedPlayerIds: Set<UUID> = []
    var seamstressUsedPlayerIds: Set<UUID> = []
    var poisonerPoisonedPlayerId: UUID?
    var poisonerPoisonSourcePlayerId: UUID?
    var pukkaPoisonedPlayerId: UUID?
    var poChargedPlayerIds: Set<UUID> = []
    var sweetheartDrunkPlayerId: UUID?
    var temporaryDrunkPlayerUntilDayNumbers: [UUID: Int] = [:]
    var temporaryDrunkPlayerSources: [UUID: String] = [:]
    var temporaryDrunkRoleUntilDayNumbers: [String: Int] = [:]
    var temporaryDrunkRoleSources: [String: String] = [:]
    var noDashiiPoisonedPlayerIds: Set<UUID> = []
    var fangGuJumpUsedPlayerIds: Set<UUID> = []
    var demonVotedTodayFlag: Bool = false
    var minionNominatedTodayFlag: Bool = false
    var didDeathOccurToday: Bool = false
    var witchCursedPlayerId: UUID?
    var mastermindExtraDayActive: Bool = false
    var alignmentOverrides: [UUID: Bool] = [:]
    var nominationNominatorByNominee: [UUID: UUID] = [:]
    var artistUsedPlayerIds: Set<UUID> = []
    var fishermanUsedPlayerIds: Set<UUID> = []
    var amnesiacUsedByDay: [UUID: Set<Int>] = [:]
    var engineerUsedPlayerIds: Set<UUID> = []
    var savantUsedByDay: [UUID: Set<Int>] = [:]
    var gossipUsedByDay: [UUID: Set<Int>] = [:]
    var gossipKillTonight: Bool = false
    var currentActionLogToneOverride: LogTone?
    var jugglerGuessesByPlayerId: [UUID: String] = [:]
    var jugglerResolvedPlayerIds: Set<UUID> = []
    var psychopathUsedByDay: [UUID: Set<Int>] = [:]
    var wizardUsedPlayerIds: Set<UUID> = []
    var minstrelDrunkUntilDayNumber: Int?
    var pacifistSavedPlayerIds: Set<UUID> = []
    var moonchildPendingPlayerId: UUID?
    var moonchildPendingTargetId: UUID?
    var zombuulSpentPlayerIds: Set<UUID> = []
    var evilTwinPlayerId: UUID?
    var evilTwinGoodPlayerId: UUID?
    var vigormortisEmpoweredMinionIds: Set<UUID> = []
    var vigormortisPoisonedNeighborIds: Set<UUID> = []
    var isVirginExecuting: Bool = false

    var selectedBaseTemplate: ScriptTemplate {
        scriptCatalog.baseTemplate(for: selectedTemplateId) ?? templates[0]
    }

    var phaseTemplate: ScriptTemplate {
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

    func roleTemplate(for id: String) -> RoleTemplate? {
        scriptCatalog.roleTemplate(
            for: id,
            templateId: selectedTemplateId,
            includingExperimental: experimentalEditionIds.contains(selectedTemplateId)
        )
    }
}

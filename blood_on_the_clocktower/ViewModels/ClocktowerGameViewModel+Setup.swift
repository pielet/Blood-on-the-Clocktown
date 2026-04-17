import Foundation
import SwiftUI

extension ClocktowerGameViewModel {

    // MARK: - Experimental editions

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

    // MARK: - Role display helpers

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

    var canReturnToPreviousStage: Bool {
        previousSetupPhase(for: phase) != nil
    }

    func returnToPreviousStage() {
        guard let previousPhase = previousSetupPhase(for: phase) else { return }
        selectedDeckCardId = nil
        currentNightTargets.removeAll()
        currentNightNote = ""
        currentNightAlignmentSelections.removeAll()
        phase = previousPhase
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

    func previousSetupPhase(for phase: PhaseType) -> PhaseType? {
        switch phase {
        case .templateSelection:
            return nil
        case .playerSetup:
            return .templateSelection
        case .assignment:
            return .playerSetup
        case .impBluffs:
            return .assignment
        case .impBluffsReveal:
            return .impBluffs
        case .firstNight, .day, .night, .finished:
            return nil
        }
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

    func deckTeamCounts() -> (townsfolk: Int, outsiders: Int, minions: Int, demons: Int) {
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

    func pickUniqueRoleIds(from templates: [RoleTemplate], count: Int, excluding excluded: Set<String> = []) -> [String] {
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

    func assignRoleCard(_ cardId: UUID, to playerId: UUID) {
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

    // MARK: - Grimoire

    func toggleGrimoire() {
        isGrimoireShowingBacks.toggle()
        if isGrimoireShowingBacks {
            clearGrimoireReveals()
        } else {
            revealedGrimoireCardIds = Set(roleDeck.map(\.id))
        }
    }
}

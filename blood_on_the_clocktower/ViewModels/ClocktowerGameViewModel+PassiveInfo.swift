import Foundation

extension ClocktowerGameViewModel {

    // MARK: - Passive Info Result Selection

    var currentNightUsesPassiveInfoSelection: Bool {
        guard let roleId = currentNightStep?.roleId else { return false }
        return ["empath", "chef"].contains(roleId)
    }

    func currentNightPassiveInfoSelectionPrompt() -> String {
        guard let roleId = currentNightStep?.roleId else { return ui("Choose the result shown.", "选择要展示的结果。") }
        switch roleId {
        case "empath":
            return ui("Choose the Empath result shown.", "选择要展示给共情者的结果。")
        case "chef":
            return ui("Choose the Chef result shown.", "选择要展示给厨师的结果。")
        default:
            return ui("Choose the result shown.", "选择要展示的结果。")
        }
    }

    var currentNightPassiveInfoSuggestedNote: String? {
        guard let roleId = currentNightStep?.roleId else { return nil }
        switch roleId {
        case "empath":
            guard let actor = currentNightActor else { return nil }
            return String(empathVisibleEvilNeighborCount(for: actor))
        case "chef":
            return String(chefVisibleAdjacentEvilPairCount())
        default:
            return nil
        }
    }

    func currentNightPassiveInfoSelectableNotes() -> [String] {
        guard let roleId = currentNightStep?.roleId else { return [] }
        switch roleId {
        case "empath":
            return Array(0...2).map(String.init)
        case "chef":
            if shouldAllowAnyPassiveInfoResult(for: roleId) {
                return Array(0...orderedSeatedPlayers().filter(\.alive).count).map(String.init)
            }
            let possibleCounts = chefPossibleAdjacentEvilPairCounts()
            if possibleCounts.isEmpty, let suggested = currentNightPassiveInfoSuggestedNote {
                return [suggested]
            }
            return possibleCounts.map(String.init)
        default:
            return []
        }
    }

    func currentNightPassiveInfoSummaryText() -> String? {
        guard let roleId = currentNightStep?.roleId,
              let suggested = currentNightPassiveInfoSuggestedNote else {
            return nil
        }

        let alignmentChoices = currentNightAlignmentChoicePlayers()
        switch roleId {
        case "empath":
            if shouldAllowAnyPassiveInfoResult(for: roleId) {
                return ui(
                    "Auto-calculated result: \(suggested). The Empath is poisoned or drunk, so the Storyteller may choose any result.",
                    "自动计算结果：\(suggested)。共情者当前中毒或醉酒，说书人可以改给任意结果。"
                )
            }
            if !alignmentChoices.isEmpty {
                return ui(
                    "Auto-calculated result: \(suggested). Adjust the Spy/Recluse registration below if needed.",
                    "自动计算结果：\(suggested)。如有需要，可在下方调整间谍/隐士的登记阵营。"
                )
            }
            return ui(
                "Auto-calculated result: \(suggested).",
                "自动计算结果：\(suggested)。"
            )
        case "chef":
            let possibleCounts = chefPossibleAdjacentEvilPairCounts()
            if shouldAllowAnyPassiveInfoResult(for: roleId) {
                return ui(
                    "Auto-calculated result: \(suggested). The Chef is poisoned or drunk, so the Storyteller may choose any number.",
                    "自动计算结果：\(suggested)。厨师当前中毒或醉酒，说书人可以改给任意数字。"
                )
            }
            if possibleCounts.count > 1 {
                let englishCounts = possibleCounts.map(String.init).joined(separator: ", ")
                let chineseCounts = possibleCounts.map(String.init).joined(separator: "、")
                return ui(
                    "Possible results: \(englishCounts). This depends on how Spy/Recluse register.",
                    "可能结果：\(chineseCounts)。具体取决于间谍/隐士如何登记。"
                )
            }
            return ui(
                "Auto-calculated result: \(suggested).",
                "自动计算结果：\(suggested)。"
            )
        default:
            return nil
        }
    }

    private func shouldAllowAnyPassiveInfoResult(for roleId: String) -> Bool {
        guard let actor = currentNightActor else { return false }
        return isAbilitySuppressed(actor) || isDisplayedDrunk(actor, actingAs: roleId)
    }

    private func empathVisibleEvilNeighborCount(for actor: PlayerCard) -> Int {
        aliveNeighbors(of: actor).reduce(into: 0) { count, neighbor in
            if detectedIsEvil(neighbor) {
                count += 1
            }
        }
    }

    private func chefVisibleAdjacentEvilPairCount() -> Int {
        chefAdjacentEvilPairCount { player in
            detectedIsEvil(player)
        }
    }

    private func chefPossibleAdjacentEvilPairCounts() -> [Int] {
        let unresolvedFlexiblePlayers = players.filter { player in
            player.alive &&
            isFlexibleRegistrationPlayer(player) &&
            currentNightAlignmentSelections[player.id] == nil
        }
        guard !unresolvedFlexiblePlayers.isEmpty else {
            return [chefVisibleAdjacentEvilPairCount()]
        }

        var selections = currentNightAlignmentSelections
        var possibleCounts: Set<Int> = []
        collectChefPossibleCounts(
            unresolvedFlexiblePlayers,
            index: 0,
            selections: &selections,
            possibleCounts: &possibleCounts
        )
        return possibleCounts.sorted()
    }

    private func collectChefPossibleCounts(
        _ unresolvedFlexiblePlayers: [PlayerCard],
        index: Int,
        selections: inout [UUID: Bool],
        possibleCounts: inout Set<Int>
    ) {
        if index == unresolvedFlexiblePlayers.count {
            possibleCounts.insert(
                chefAdjacentEvilPairCount { player in
                    selections[player.id] ?? isPlayerEvil(player)
                }
            )
            return
        }

        let player = unresolvedFlexiblePlayers[index]
        selections[player.id] = false
        collectChefPossibleCounts(
            unresolvedFlexiblePlayers,
            index: index + 1,
            selections: &selections,
            possibleCounts: &possibleCounts
        )

        selections[player.id] = true
        collectChefPossibleCounts(
            unresolvedFlexiblePlayers,
            index: index + 1,
            selections: &selections,
            possibleCounts: &possibleCounts
        )

        selections.removeValue(forKey: player.id)
    }

    private func chefAdjacentEvilPairCount(using isEvil: (PlayerCard) -> Bool) -> Int {
        let livingPlayers = orderedSeatedPlayers().filter(\.alive)
        guard livingPlayers.count >= 2 else { return 0 }

        var count = 0
        for index in livingPlayers.indices {
            let player = livingPlayers[index]
            let nextPlayer = livingPlayers[(index + 1) % livingPlayers.count]
            if isEvil(player) && isEvil(nextPlayer) {
                count += 1
            }
        }
        return count
    }
}

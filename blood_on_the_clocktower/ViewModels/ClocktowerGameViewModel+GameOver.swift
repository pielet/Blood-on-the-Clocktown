import Foundation

extension ClocktowerGameViewModel {

    // MARK: - Game Over

    func gameOverCheck() {
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

    func evilHasPossibleWinningPath(alivePlayers: [PlayerCard]) -> Bool {
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

    func setGameOver(reason: GameOverReason, side: WinningSide) {
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

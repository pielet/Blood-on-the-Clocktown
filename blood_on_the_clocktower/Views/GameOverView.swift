import SwiftUI

struct GameOverView: View {
    @EnvironmentObject private var game: ClocktowerGameViewModel

    var body: some View {
        VStack(spacing: 16) {
            finalRolesPanel

            if let message = game.gameOverMessage {
                Text(message)
                    .font(.headline.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(game.winningSide == .evil ? .red : .green)
                    .accessibilityIdentifier("gameover-winner")
            }

            Button(game.restartButtonTitle) {
                game.resetGame()
            }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier("gameover-restart")
        }
    }

    private var finalRolesPanel: some View {
        GroupBox(game.ui("Final Roles", "最终角色")) {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(game.players) { player in
                    playerRoleHistory(player: player)
                }
            }
        }
    }

    private func playerRoleHistory(player: PlayerCard) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(player.name)
                    .font(.subheadline.weight(.semibold))

                if let baseRole = baseRole(for: player) {
                    roleBadge(baseRole, isCurrent: player.roleId == baseRole.id)
                }
            }

            Spacer(minLength: 8)

            if let currentRole = transferredRole(for: player) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.right")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    roleBadge(currentRole, isCurrent: true)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func baseRole(for player: PlayerCard) -> RoleTemplate? {
        if let originalRoleId = player.originalRoleId,
           let originalRole = game.roleTemplate(for: originalRoleId) {
            return originalRole
        }

        if let roleId = player.roleId,
           let role = game.roleTemplate(for: roleId) {
            return role
        }

        return nil
    }

    private func transferredRole(for player: PlayerCard) -> RoleTemplate? {
        guard let originalRoleId = player.originalRoleId,
              let currentRoleId = player.roleId,
              currentRoleId != originalRoleId else {
            return nil
        }

        return game.roleTemplate(for: currentRoleId)
    }

    private func roleBadge(_ role: RoleTemplate, isCurrent: Bool) -> some View {
        HStack(spacing: 6) {
            RoleIconImage(role: role)
                .frame(width: 20, height: 20)
            Text(game.localizedRoleName(role))
                .font(.caption)
                .foregroundStyle(isCurrent ? .primary : .secondary)
                .lineLimit(1)
        }
        .fixedSize(horizontal: true, vertical: false)
    }
}

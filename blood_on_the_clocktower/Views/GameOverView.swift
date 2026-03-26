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
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(game.players) { player in
                    playerRoleHistory(player: player)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func playerRoleHistory(player: PlayerCard) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Text(player.name)
                .font(.body.weight(.semibold))
                .lineLimit(1)

            Spacer(minLength: 12)

            if let baseRole = baseRole(for: player) {
                roleTransition(baseRole: baseRole, currentRole: transferredRole(for: player), isBaseCurrent: player.roleId == baseRole.id)
                    .frame(maxWidth: .infinity, alignment: .trailing)
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

    private func roleTransition(baseRole: RoleTemplate, currentRole: RoleTemplate?, isBaseCurrent: Bool) -> some View {
        HStack(spacing: 6) {
            roleBadge(baseRole, isCurrent: isBaseCurrent)

            if let currentRole {
                Image(systemName: "arrow.right")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                roleBadge(currentRole, isCurrent: true)
            }
        }
    }

    private func roleBadge(_ role: RoleTemplate, isCurrent: Bool) -> some View {
        HStack(spacing: 6) {
            RoleIconImage(role: role)
                .frame(width: 22, height: 22)
            Text(game.localizedRoleName(role))
                .font(.footnote)
                .foregroundStyle(isCurrent ? .primary : .secondary)
                .lineLimit(1)
        }
        .fixedSize(horizontal: true, vertical: false)
    }
}

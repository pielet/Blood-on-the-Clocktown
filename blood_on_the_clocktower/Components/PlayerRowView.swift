import SwiftUI

private func playerRowBackgroundColor(isAlive: Bool) -> Color {
    isAlive ? Color.gray.opacity(0.12) : Color.black.opacity(0.14)
}

struct PlayerRowView: View {
    @EnvironmentObject private var game: ClocktowerGameViewModel
    let player: PlayerCard
    let role: RoleTemplate?
    let latestLog: String
    let isExpanded: Bool
    let onToggleExpanded: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: onToggleExpanded) {
                header
            }
            .buttonStyle(.plain)
            .zIndex(1)
            .accessibilityIdentifier("player-row-\(player.seatNumber)")

            if isExpanded {
                VStack(alignment: .leading, spacing: 10) {
                    Divider()
                    roleDetailSection
                    statusSection
                    logSection
                }
                .padding(.top, 8)
                .transition(.opacity)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(playerRowBackgroundColor(isAlive: player.alive))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.black.opacity(0.08), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .animation(.easeInOut(duration: 0.22), value: isExpanded)
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 8) {
            Circle()
                .fill(player.alive ? Color.green : Color.red)
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(player.name)
                        .font(.subheadline.bold())
                        .foregroundStyle(player.alive ? .primary : .secondary)

                    if let role {
                        RoleIconImage(role: role)
                            .frame(width: 22, height: 22)
                        Text(game.localizedRoleName(role))
                            .font(.caption.weight(.semibold))
                            .lineLimit(1)
                    } else {
                        Text(game.ui("Unassigned", "未分配"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if game.isPlayerExternallyPoisonedOrDrunk(player) {
                        poisonedStatusIcon(font: .caption.weight(.semibold), size: 24)
                    }
                }

                if !latestLog.isEmpty {
                    Text(game.localizedRecordedLog(latestLog))
                        .font(.caption2)
                        .foregroundStyle(game.color(forRecordedLog: latestLog))
                        .lineLimit(2)
                }
            }

            Spacer()

            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
        }
    }

    private var roleDetailSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(game.ui("Role", "角色信息"))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            if let role {
                Text(game.localizedRoleName(role))
                    .font(.subheadline.weight(.semibold))
                Text(game.localizedRoleSummary(role))
                    .font(.caption)
                Text(game.localizedRoleDetail(role))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text(game.ui("No role information.", "暂无角色信息"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(game.ui("Status", "状态"))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            let statusItems = game.playerStatusItems(for: player)
            if statusItems.isEmpty {
                Text(game.ui("No extra status.", "当前无额外状态"))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(statusItems, id: \.self) { item in
                        HStack(spacing: 4) {
                            if item.contains("Poisoned") || item.contains("中毒") {
                                poisonedStatusIcon(font: .caption2, size: 20)
                            }
                            Text(item)
                                .font(.caption2)
                        }
                    }
                }
            }
        }
    }

    private var logSection: some View {
        let visibleLogs = filteredLogs()

        return VStack(alignment: .leading, spacing: 6) {
            Text(game.ui("Logs", "日志"))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            if visibleLogs.isEmpty {
                Text(game.ui("No logs yet.", "暂无日志"))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(visibleLogs.enumerated()), id: \.offset) { _, item in
                        Text(game.localizedRecordedLog(item))
                            .font(.caption2)
                            .foregroundStyle(game.color(forRecordedLog: item))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    private func filteredLogs() -> [String] {
        player.roleLog.filter {
            !$0.hasPrefix("Assigned role:") && !$0.hasPrefix("分配角色：")
        }
    }

    private func poisonedStatusIcon(font: Font, size: CGFloat) -> some View {
        Image("poisoned_status")
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .foregroundStyle(Color(red: 0.3, green: 0.0, blue: 0.4))
            .accessibilityHidden(true)
            .font(font)
    }
}

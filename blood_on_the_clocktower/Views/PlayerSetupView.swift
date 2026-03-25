import SwiftUI

struct PlayerSetupView: View {
    @EnvironmentObject private var game: ClocktowerGameViewModel
    @State private var count: Int = 7
    @State private var deckReady = false
    private let limits = 5...20
    private let dayTimerPresets: [Int] = [300, 600, 900, 1200]
    private let drunkChoiceColumns = [
        GridItem(.adaptive(minimum: 140, maximum: 220), spacing: 10)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(game.ui("Players and Role Pool", "玩家人数与牌池"))
                    .font(.headline)

                Stepper(value: $count, in: limits) {
                    Text("\(game.ui("Players", "玩家数")): \(count)")
                        .font(.title3)
                }
                .accessibilityIdentifier("setup-stepper")
                .onChange(of: count) {
                    game.setPlayerCount(count)
                    deckReady = false
                }

                Text(game.roleDeck.isEmpty ? game.expectedTeamDistribution : game.selectedDeckTeamDistribution)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(alignment: .center, spacing: 12) {
                    Text(game.ui("Name Prefix", "名称前缀"))
                        .font(.subheadline)
                    TextField(game.ui("P", "P"), text: $game.playerNamePrefix)
                        .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(game.ui("Day Timer", "白天计时"))
                        .font(.subheadline)
                    Picker("Day Timer", selection: $game.dayPreset) {
                        ForEach(dayTimerPresets, id: \.self) { preset in
                            Text(dayTimerLabel(for: preset)).tag(preset)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Divider()

                if !game.roleDeck.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(game.roleDeck) { card in
                                selectedRoleChip(for: card.roleId)
                            }
                        }
                        .padding(.horizontal, 4)
                        .padding(.vertical, 6)
                    }
                    .transaction { transaction in
                        transaction.animation = nil
                    }
                }

                if !game.drunkCards.isEmpty {
                    drunkSelectionPanel
                }

                Button(deckReady ? game.ui("Draw Roles Again", "重新抽取角色牌") : game.ui("Draw Roles", "抽取角色牌")) {
                    var transaction = Transaction()
                    transaction.disablesAnimations = true
                    withTransaction(transaction) {
                        game.setPlayerCount(count)
                        game.buildDeck()
                        deckReady = true
                    }
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("setup-drawRoles")

                Button(game.ui("Assign Roles", "开始发牌")) {
                    game.playerSetup()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!deckReady || !game.canStartRoleAssignment)
                .accessibilityIdentifier("setup-assignRoles")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .onAppear {
            count = game.playerCount
            deckReady = !game.roleDeck.isEmpty
        }
    }

    private func selectedRoleChip(for roleId: String) -> some View {
        let role = game.roleTemplate(for: roleId)
        let fill: Color
        let stroke: Color

        switch role?.team {
        case .townsfolk:
            fill = Color.blue.opacity(0.14)
            stroke = Color.blue.opacity(0.35)
        case .outsider:
            fill = Color.orange.opacity(0.16)
            stroke = Color.orange.opacity(0.42)
        case .minion:
            fill = Color.red.opacity(0.14)
            stroke = Color.red.opacity(0.35)
        case .demon:
            fill = Color.red.opacity(0.22)
            stroke = Color.red.opacity(0.55)
        case .traveller, .none:
            fill = Color.gray.opacity(0.14)
            stroke = Color.gray.opacity(0.32)
        }

        return VStack(spacing: 4) {
            RoleIconImage(role: role)
                .frame(width: 38, height: 38)
            Text(game.localizedRoleName(role))
                .font(.caption2)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(width: 76, height: 80)
        .padding(4)
        .background(fill)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(stroke, lineWidth: 1)
        )
    }

    private var drunkSelectionPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(game.ui("Drunk Shown Role", "酒鬼展示角色"))
                .font(.headline)

            Text(game.ui("Choose which Townsfolk role each Drunk believes they are before role assignment starts.", "在发牌开始前，为每张酒鬼牌选择其自认为的镇民角色。"))
                .font(.caption)
                .foregroundStyle(.secondary)

            ForEach(Array(game.drunkCards.enumerated()), id: \.element.id) { index, card in
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        RoleIconImage(role: game.roleTemplate(for: card.roleId))
                            .frame(width: 24, height: 24)
                        Text(game.drunkCards.count > 1 ? game.ui("Drunk \(index + 1)", "酒鬼 \(index + 1)") : game.ui("Drunk", "酒鬼"))
                            .font(.subheadline.weight(.semibold))
                        if let shownRoleId = card.displayedRoleId,
                           let shownRole = game.roleTemplate(for: shownRoleId) {
                            Text(game.ui("Shown as \(game.localizedRoleName(shownRole))", "展示为 \(game.localizedRoleName(shownRole))"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    LazyVGrid(columns: drunkChoiceColumns, spacing: 10) {
                        ForEach(game.availableDrunkDisplayRoles(for: card.id)) { role in
                            drunkRoleChoiceButton(cardId: card.id, role: role, isSelected: card.displayedRoleId == role.id)
                        }
                    }
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.gray.opacity(0.08))
                )
            }
        }
    }

    private func drunkRoleChoiceButton(cardId: UUID, role: RoleTemplate, isSelected: Bool) -> some View {
        Button {
            game.selectDisplayedRoleForDrunkCard(cardId, roleId: role.id)
        } label: {
            HStack(spacing: 8) {
                RoleIconImage(role: role)
                    .frame(width: 22, height: 22)
                Text(game.localizedRoleName(role))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(isSelected ? .white : .primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? Color.blue : Color.white.opacity(0.96))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? Color.blue : Color.black.opacity(0.08), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func dayTimerLabel(for seconds: Int) -> String {
        let minutes = seconds / 60
        return game.ui("\(minutes) min", "\(minutes)分钟")
    }

}

#if DEBUG
struct PlayerSetupView_Previews: PreviewProvider {
    static var previews: some View {
        PlayerSetupView()
            .environmentObject(ClocktowerGameViewModel())
    }
}
#endif

import SwiftUI

struct ImpBluffSetupView: View {
    @EnvironmentObject private var game: ClocktowerGameViewModel

    private let columns = [
        GridItem(.adaptive(minimum: 112, maximum: 160), spacing: 12)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            availableRolesSection
            continueButton
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(
                game.ui(
                    "Choose 3 bluff roles.",
                    "选择 3 个诈唬角色。"
                )
            )
            .font(.headline)

            if let impPlayer = game.impPlayerForSetup {
                Text(
                    game.ui(
                        "Show to \(impPlayer.name). In-play good roles never appear. If the Drunk is in play, the role they think they are also will not appear.",
                        "展示给 \(impPlayer.name)。已在场的善良角色不会出现。若酒鬼在场，其自认为的角色也不会出现。"
                    )
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
    }

    private var availableRolesSection: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(game.availableImpBluffRoles) { role in
                    bluffRoleButton(role: role)
                        .accessibilityIdentifier("impbluff-role-\(role.id)")
                }
            }
            .padding(.vertical, 4)
        }
    }

    private func bluffRoleButton(role: RoleTemplate) -> some View {
        let isSelected = game.impBluffRoleIds.contains(role.id)

        return Button {
            game.toggleImpBluffRole(role.id)
        } label: {
            VStack(spacing: 8) {
                RoleIconImage(role: role)
                    .frame(width: 52, height: 52)
                Text(game.localizedRoleName(role))
                    .font(.caption.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.75)
            }
            .frame(maxWidth: .infinity, minHeight: 108)
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.green.opacity(0.18) : Color.gray.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.green.opacity(0.8) : Color.black.opacity(0.08), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var continueButton: some View {
        Button(game.ui("Show to Imp", "展示给小恶魔")) {
            game.confirmImpBluffSelection()
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .frame(maxWidth: .infinity)
        .disabled(!game.isImpBluffSelectionReady)
        .accessibilityIdentifier("impbluff-showToImp")
    }
}

#if DEBUG
struct ImpBluffSetupView_Previews: PreviewProvider {
    static var previews: some View {
        ImpBluffSetupView()
            .environmentObject(ClocktowerGameViewModel())
    }
}
#endif

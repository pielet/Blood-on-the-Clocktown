import SwiftUI

struct ImpBluffRevealView: View {
    @EnvironmentObject private var game: ClocktowerGameViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header
            bluffRow
            continueButton
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let impPlayer = game.impPlayerForSetup {
                Text(
                    game.ui(
                        "Reveal to \(impPlayer.name), then continue into the night.",
                        "展示给 \(impPlayer.name)，然后继续入夜。"
                    )
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
    }

    private var bluffRow: some View {
        HStack(spacing: 16) {
            ForEach(game.selectedImpBluffRoles) { role in
                VStack(spacing: 10) {
                    RoleIconImage(role: role)
                        .frame(width: 70, height: 70)

                    Text(game.localizedRoleName(role))
                        .font(.headline)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)

                    Text(game.localizedTeamName(role.team))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 170)
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(ImpBluffRoleTagStyle.cardFill)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(ImpBluffRoleTagStyle.cardBorder, lineWidth: 1)
                )
            }
        }
    }

    private var continueButton: some View {
        Button(game.ui("Night Falls", "入夜")) {
            game.confirmImpBluffsAndBeginNight()
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .frame(maxWidth: .infinity)
        .accessibilityIdentifier("impbluffreveal-nightFalls")
    }
}

#if DEBUG
struct ImpBluffRevealView_Previews: PreviewProvider {
    static var previews: some View {
        ImpBluffRevealView()
            .environmentObject(ClocktowerGameViewModel())
    }
}
#endif

import SwiftUI

struct AssignmentView: View {
    @EnvironmentObject private var game: ClocktowerGameViewModel

    private let activeCardBackAsset = "card_back_active_flat"
    private let inactiveCardBackAsset = "card_back_inactive_flat"
    private let assignmentColumns = [
        GridItem(.adaptive(minimum: 104, maximum: 152), spacing: 18)
    ]

    var body: some View {
        VStack(spacing: 18) {
            cardGrid
            beginNightButton
        }
    }

    private var cardGrid: some View {
        ScrollView {
            LazyVGrid(columns: assignmentColumns, spacing: 18) {
                ForEach(Array(game.roleDeck.enumerated()), id: \.element.id) { index, card in
                    assignmentCard(for: card)
                        .accessibilityIdentifier("assignment-card-\(index)")
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
        }
    }

    private var beginNightButton: some View {
        Button(game.ui("Night Falls", "入夜")) {
            game.continueFromAssignment()
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .frame(maxWidth: .infinity)
        .disabled(!game.isAssignmentReady)
        .accessibilityIdentifier("assignment-nightFalls")
    }

    @ViewBuilder
    private func assignmentCard(for card: RoleDeckCard) -> some View {
        let isFront = card.state == .front
        let isUsed = card.state == .used
        let showsInactiveBack = isFront || isUsed
        let isInteractionBlocked = game.selectedDeckCardId != nil && game.selectedDeckCardId != card.id

        Button {
            withAnimation(.easeInOut(duration: 0.4)) {
                game.flipDeckCard(card.id)
            }
        } label: {
            FlipCardView(isFlipped: isFront) {
                assignmentCardFront(card: card)
            } back: {
                assignmentCardBack(isUsed: showsInactiveBack)
            }
            .frame(height: 156)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .contentShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .disabled(isUsed || isInteractionBlocked)
        .opacity(isInteractionBlocked ? 0.55 : 1)
    }

    private func assignmentCardFront(card: RoleDeckCard) -> some View {
        let role = game.assignmentDisplayRole(for: card)

        return VStack(spacing: 10) {
            if let role {
                RoleIconImage(role: role)
                    .frame(width: 58, height: 58)

                Text(game.localizedRoleName(role))
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.75)

                Text(game.localizedTeamName(role.team))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
            } else {
                Image(systemName: "questionmark.circle.fill")
                    .font(.system(size: 46, weight: .semibold))
                    .foregroundStyle(.secondary)

                Text(game.ui("Choose shown Townsfolk", "选择展示镇民"))
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)

                Text(game.ui("Storyteller picks what the Drunk believes.", "由说书人选择酒鬼自认为的角色。"))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(
                    LinearGradient(
                        colors: [Color.white, Color(red: 0.92, green: 0.95, blue: 0.98)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.black.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.08), radius: 8, y: 4)
    }

    private func assignmentCardBack(isUsed: Bool) -> some View {
        ZStack {
            Image(isUsed ? inactiveCardBackAsset : activeCardBackAsset)
                .resizable()
                .scaledToFill()
                .overlay(.black.opacity(isUsed ? 0.26 : 0.04))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isUsed ? Color.black.opacity(0.18) : Color.white.opacity(0.16), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(isUsed ? 0.08 : 0.16), radius: 8, y: 4)
    }
}

#if DEBUG
struct AssignmentView_Previews: PreviewProvider {
    static var previews: some View {
        AssignmentView()
            .environmentObject(ClocktowerGameViewModel())
    }
}
#endif

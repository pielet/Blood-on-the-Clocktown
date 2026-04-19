import SwiftUI

struct FlipCardView<Front: View, Back: View>: View {
    let isFlipped: Bool
    @ViewBuilder let front: () -> Front
    @ViewBuilder let back: () -> Back

    var body: some View {
        ZStack {
            back()
                .opacity(isFlipped ? 0 : 1)

            front()
                .scaleEffect(x: -1, y: 1)
                .opacity(isFlipped ? 1 : 0)
        }
        .rotation3DEffect(
            .degrees(isFlipped ? 180 : 0),
            axis: (x: 0, y: 1, z: 0),
            perspective: 0.4
        )
    }
}

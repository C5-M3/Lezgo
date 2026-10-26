import SwiftUI

/// The top card on the trip map: an arrow, the distance to the next turn and the turn instruction.
struct TripMapTurnCard: View {
    let guidance: TripMapGuidance
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading))
            : AnyLayout(HStackLayout(spacing: 16))

        layout {
            Image(systemName: ArrowSymbol())
                .font(.largeTitle.bold())
                .accessibilityHidden(true)

            VStack(alignment: .leading) {
                Text(guidance.distanceToTurn.formatted(.measurement(width: .abbreviated, usage: .road)))
                    .font(.largeTitle.bold())
                // Primary, not secondary: grey text on glass over a bright map falls below 4.5:1 contrast.
                Text(guidance.instruction)
                    .font(.title3)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(in: .rect(cornerRadius: 24))
        .accessibilityElement(children: .combine)
    }

    private func ArrowSymbol() -> String {
        switch guidance.direction {
        case .left: "arrow.turn.up.left"
        case .right: "arrow.turn.up.right"
        case .straight: "arrow.up"
        }
    }
}

#Preview("Turn right") {
    TripMapTurnCard(
        guidance: TripMapGuidance(
            direction: .right,
            instruction: "Turn right",
            distanceToTurn: Measurement(value: 200, unit: .meters),
            timeLeft: .seconds(3_000)
        )
    )
    .padding()
}

#Preview("Long instruction, largest text") {
    TripMapTurnCard(
        guidance: TripMapGuidance(
            direction: .left,
            instruction: "Turn left onto Jalan Mayjen Sungkono, then keep left at the fork towards Pakuwon",
            distanceToTurn: Measurement(value: 1_250, unit: .meters),
            timeLeft: .seconds(3_000)
        )
    )
    .padding()
    .dynamicTypeSize(.accessibility5)
}

//
//  TripMapTurnCard.swift
//  Lezgo
//
//  Created by Nathan Sudiara on 26/10/26.
//

import SwiftUI

/// The top card on the trip map: an arrow, the distance to the next turn and the turn instruction.
struct TripMapTurnCard: View {
    let guidance: TripMapGuidance
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .largeTitle) private var distanceSize = 46
    @ScaledMetric(relativeTo: .largeTitle) private var arrowSize = 52

    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading))
            : AnyLayout(HStackLayout(spacing: 22))

        layout {
            Image(systemName: guidance.direction.symbolName)
                .font(.system(size: arrowSize, weight: .bold))
                .foregroundStyle(Color(.brandYellow))
                // The new arrow replaces the old one instead of blinking in.
                .contentTransition(.symbolEffect(.replace))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(guidance.distanceToTurn.formatted(.measurement(width: .abbreviated, usage: .road)))
                    .font(.system(size: distanceSize, weight: .heavy))
                    .foregroundStyle(Color(.tripCardText))
                    // The distance counts down every second; rolling digits read calmer than jumping ones.
                    .contentTransition(.numericText(countsDown: true))
                Text(guidance.instruction)
                    .font(.callout)
                    .foregroundStyle(Color(.tripCardSubtext))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.tripCard), in: .rect(cornerRadius: 30))
        .animation(Animation.lezgoSwap.Respecting(reduceMotion: reduceMotion), value: guidance)
        .accessibilityElement(children: .combine)
    }
}

extension TripMapTurnCard {
    /// The turn card while a new route is on its way (lo-fi `B6 Rerouting (leader)`): the old turn would point the
    /// wrong way, and a card that just stops changing looks like the app froze. Shown in place of the turn card, so
    /// it adds nothing on top of the map.
    struct Rerouting: View {
        /// The leader finds a new route for everyone; a member finds their own way back to the group.
        let isLeader: Bool
        @Environment(\.accessibilityReduceMotion) private var reduceMotion

        var body: some View {
            HStack(spacing: 16) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.largeTitle.bold())
                    .foregroundStyle(Color(.brandYellow))
                    .symbolEffect(.rotate, options: .repeat(.continuous), isActive: reduceMotion == false)
                    .accessibilityHidden(true)

                VStack(alignment: .leading) {
                    Text(.tripMapRerouting)
                        .font(.largeTitle.bold())
                        .foregroundStyle(Color(.tripCardText))
                    Text(isLeader ? .tripMapReroutingLeader : .tripMapReroutingMember)
                        .font(.callout)
                        .foregroundStyle(Color(.tripCardSubtext))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.tripCard), in: .rect(cornerRadius: 30))
            .accessibilityElement(children: .combine)
        }
    }
}

#Preview("Rerouting, leader and member") {
    VStack {
        TripMapTurnCard.Rerouting(isLeader: true)
        TripMapTurnCard.Rerouting(isLeader: false)
    }
    .padding()
}

#Preview("Rerouting, largest text") {
    TripMapTurnCard.Rerouting(isLeader: false)
        .padding()
        .dynamicTypeSize(.accessibility5)
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

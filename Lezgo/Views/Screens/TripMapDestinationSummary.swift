//
//  TripMapDestinationSummary.swift
//  Lezgo
//
//  Created by Nathan Sudiara on 26/10/26.
//

import SwiftUI

/// The top of the trip map's bottom card while driving: where the trip goes and how long is left.
struct TripMapDestinationSummary: View {
    let destinationName: String
    /// `nil` until the first guidance arrives; the summary then shows only the destination.
    let timeLeft: Duration?

    @ScaledMetric(relativeTo: .largeTitle) private var timeSize = 36
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(.tripMapToDestination(destinationName))
                .font(.title3.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)
            if let timeLeft {
                Text(timeLeft.formatted(TripMapCarStatus.durationStyle))
                    .font(.system(size: timeSize, weight: .black))
                    .foregroundStyle(Color(.brandYellow))
                    .fixedSize(horizontal: false, vertical: true)
                    .contentTransition(.numericText(countsDown: true))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .animation(Animation.lezgoSwap.Respecting(reduceMotion: reduceMotion), value: timeLeft)
        .accessibilityElement(children: .combine)
    }
}

#Preview("With time left") {
    TripMapDestinationSummary(destinationName: "Tunjungan Plaza", timeLeft: .seconds(3_000))
        .padding()
        .background(Color(.tripCard))
        .environment(\.colorScheme, .dark)
}

#Preview("Before guidance, long name, largest text") {
    TripMapDestinationSummary(
        destinationName: "Pakuwon Mall, Jalan Puncak Indah Lontar No. 2, Babatan, Wiyung, Surabaya",
        timeLeft: nil
    )
    .padding()
    .background(Color(.tripCard))
    .environment(\.colorScheme, .dark)
    .dynamicTypeSize(.accessibility5)
}

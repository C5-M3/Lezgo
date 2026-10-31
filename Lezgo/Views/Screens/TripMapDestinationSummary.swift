//
//  TripMapDestinationSummary.swift
//  Lezgo
//
//  Created by Nathan Sudiara on 26/10/26.
//

import SwiftUI

/// The top of the trip map sheet while driving, as in Apple Maps: where the trip goes, and the arrival time, time
/// left and distance left.
struct TripMapDestinationSummary: View {
    let destinationName: String
    /// `nil` until the first guidance arrives; the summary then shows only the destination.
    let timeLeft: Duration?
    let distanceLeft: Measurement<UnitLength>?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(.tripMapToDestination(destinationName))
                .font(.title3.bold())
                .fixedSize(horizontal: false, vertical: true)
            if let timeLeft {
                Text(Details(timeLeft: timeLeft))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    /// "Arrive 14.32 · 2 hr, 12 min · 120 km"
    private func Details(timeLeft: Duration) -> String {
        let arrival = Date.now.addingTimeInterval(TimeInterval(timeLeft.components.seconds))
        var parts = [
            String(localized: .tripMapArriveAt(arrival.formatted(date: .omitted, time: .shortened))),
            timeLeft.formatted(TripMapCarStatus.durationStyle)
        ]
        if let distanceLeft {
            parts.append(distanceLeft.formatted(.measurement(width: .abbreviated, usage: .road)))
        }
        return parts.joined(separator: " · ")
    }
}

#Preview("With time and distance left") {
    TripMapDestinationSummary(
        destinationName: "Ciputra World Surabaya",
        timeLeft: .seconds(7_920),
        distanceLeft: Measurement(value: 120_000, unit: .meters)
    )
    .padding()
}

#Preview("Before guidance, long name, largest text") {
    TripMapDestinationSummary(
        destinationName: "Pakuwon Mall, Jalan Puncak Indah Lontar No. 2, Babatan, Wiyung, Surabaya",
        timeLeft: nil,
        distanceLeft: nil
    )
    .padding()
    .dynamicTypeSize(.accessibility5)
}

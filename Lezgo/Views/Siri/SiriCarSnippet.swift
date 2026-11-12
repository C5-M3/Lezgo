//
//  SiriCarSnippet.swift
//  Lezgo
//
//  Created by Nathan Sudiara on 12/11/26.
//

import SwiftUI

/// Siri's card for "Where's the leader" and "Where's [name]" (US-08): a still map with both robots, then the car with
/// its time left. Siri says the distance and street, so the card adds what it does not say.
struct SiriCarSnippet: View {
    struct Car: Hashable {
        var name: String
        var color: TripMapCarPin.CarColor
        var isLeader: Bool
        /// "Leader · Driving", "Driving · White Jazz".
        var subtitle: String
        var timeLeft: Duration?
    }

    let car: Car
    let myColor: TripMapCarPin.CarColor
    /// "1.2 km", on the map between the cars.
    var gap: String?
    var map: SiriMapPicture?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let map {
                SiriMapView(map: map, colors: [myColor, car.color], label: gap)
            }
            HStack(spacing: 12) {
                SiriCarAvatar(color: car.color, isLeader: car.isLeader)
                VStack(alignment: .leading, spacing: 2) {
                    Text(car.name)
                        .font(.headline)
                    Text(car.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                if let timeLeft = car.timeLeft {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(timeLeft.formatted(TripMapCarStatus.durationStyle))
                            .font(.title3.bold())
                            .monospacedDigit()
                        Text(.siriToDestination)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .accessibilityElement(children: .combine)
        }
    }
}

#Preview("Leader") {
    SiriCarSnippet(
        car: .init(name: "Agus", color: .yellow, isLeader: true, subtitle: "Leader · Driving", timeLeft: .seconds(840)),
        myColor: .blue,
        gap: "1.2 km"
    )
    .padding()
}

#Preview("Long name, no time") {
    SiriCarSnippet(
        car: .init(
            name: "Bartholomew Alexander Wijaya", color: .pink, isLeader: false,
            subtitle: "Driving · White Honda Jazz RS 2019", timeLeft: nil
        ),
        myColor: .blue
    )
    .padding()
    .dynamicTypeSize(.accessibility2)
}

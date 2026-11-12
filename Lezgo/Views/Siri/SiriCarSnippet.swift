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
        VStack(alignment: .leading, spacing: 10) {
            if let map {
                SiriMapView(map: map, colors: [myColor, car.color], label: gap)
            }
            HStack(spacing: 10) {
                SiriCarAvatar(color: car.color, isLeader: car.isLeader, size: 36)
                VStack(alignment: .leading, spacing: 1) {
                    Text(car.name)
                        .font(.headline)
                        .lineLimit(1)
                    Text(car.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                Spacer(minLength: 0)
            }
            if let timeLeft = car.timeLeft {
                Label {
                    Text(.siriTimeToDestination(timeLeft.formatted(TripMapCarStatus.durationStyle)))
                } icon: {
                    Image(systemName: "clock.fill")
                }
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            }
        }
        .accessibilityElement(children: .combine)
        .padding()
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

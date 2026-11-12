//
//  SiriArrivedSnippet.swift
//  Lezgo
//
//  Created by Nathan Sudiara on 12/11/26.
//

import SwiftUI

/// Siri's card after "I've Arrived" (US-08): each car's robot with whether it has arrived, like the arrival card.
struct SiriArrivedSnippet: View {
    struct Car: Identifiable, Hashable {
        let id: UUID
        var name: String
        var color: TripMapCarPin.CarColor
        var isLeader: Bool
        var hasArrived: Bool
    }

    /// At most four cars fit; more are counted.
    static let maxCars = 4

    let cars: [Car]

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            ForEach(cars.prefix(Self.maxCars)) { car in
                VStack(spacing: 6) {
                    SiriCarAvatar(color: car.color, isLeader: car.isLeader, hasArrived: car.hasArrived, size: 56)
                    Text(car.name)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                    Text(car.hasArrived ? .siriStatusArrived : .siriStatusOnTheWay)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .combine)
            }
            if cars.count > Self.maxCars {
                Text(verbatim: "+\(cars.count - Self.maxCars)")
                    .font(.headline)
                    .frame(width: 56, height: 56)
                    .background(.fill.tertiary, in: .circle)
            }
        }
    }
}

#Preview {
    SiriArrivedSnippet(cars: [
        .init(id: UUID(), name: "You", color: .blue, isLeader: false, hasArrived: true),
        .init(id: UUID(), name: "Agus", color: .yellow, isLeader: true, hasArrived: false),
        .init(id: UUID(), name: "Citra", color: .pink, isLeader: false, hasArrived: false)
    ])
    .padding()
}

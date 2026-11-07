//
//  TripMapArrivalProgress.swift
//  Lezgo
//
//  Created by Nathan Sudiara on 05/11/26.
//

import Foundation

/// What the top card shows once this phone's car has arrived: a robot per arrived car, and the count.
struct TripMapArrivalProgress: Hashable {
    /// More robots would not fit on the card. Past this many cars only the count changes.
    static let maxRobots = 5

    /// The first cars to arrive, first one first, up to `maxRobots`.
    var robots: [Robot]
    var arrivedCount: Int
    var totalCount: Int

    /// "2/4"
    var countText: String {
        "\(arrivedCount)/\(totalCount)"
    }

    /// One arrived car on the top card.
    struct Robot: Identifiable, Hashable {
        let id: UUID
        let carColor: TripMapCarPin.CarColor
    }
}

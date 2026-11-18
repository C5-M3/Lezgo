//
//  TripMapViewModel+Participants.swift
//  Lezgo
//
//  Created by Oky Faishal on 18/11/26.
//

import Foundation

// The On the Go list the phone shows while CarPlay is connected (ADR 0034).
extension TripMapViewModel {
    /// One participant of the On the Go list: what the car is doing, and when it arrives at the destination.
    struct ParticipantRow: Identifiable, Hashable {
        let status: TripMapCarStatus
        /// `nil` until it is looked up, and for an offline car, whose last position is out of date.
        let timeToDestination: Duration?
        let isMe: Bool

        var id: UUID { status.id }
    }

    /// Every participant, in the order of the trip.
    var participantRows: [ParticipantRow] { [] }

    /// How long this car needs to reach its next stop, or `nil` until it is looked up.
    var timeToNextStop: Duration? { nil }

    /// Looks up every car's street and arrival time once, at most every 30 seconds per car (see `LookUpCar`).
    func RefreshAllCars() async {}
}

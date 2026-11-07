//
//  TripMapManualArrival.swift
//  Lezgo
//
//  Created by Nathan Sudiara on 07/11/26.
//

import Foundation
import Observation

/// "I've Arrived" (`specs/UserStories.md` → US-07, "Arrive").
@Observable
final class TripMapManualArrival {
    /// The question before saving: how far this car is from the destination's point.
    struct Confirmation: Hashable {
        let destinationID: UUID
        let destinationName: String
        let distance: Measurement<UnitLength>
    }

    private(set) var confirmation: Confirmation?
    private(set) var errorMessage: String?

    private let tripID: UUID
    private let myParticipantID: UUID
    private let tripService: any TripService

    init(tripID: UUID, myParticipantID: UUID, tripService: any TripService) {
        self.tripID = tripID
        self.myParticipantID = myParticipantID
        self.tripService = tripService
    }

    func CanMark(in state: TripState?, from myCoordinate: Coordinate?) -> Bool {
        false
    }

    func Request(in state: TripState?, from myCoordinate: Coordinate?) {}

    func Cancel() {}

    func Confirm(_ confirmation: Confirmation) async {}

    func DismissError() {}
}

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

    /// Where the cars are between the start and the end of the route, for the track on the On the Go card.
    struct RouteProgress: Hashable {
        struct Car: Identifiable, Hashable {
            let id: UUID
            let carColor: TripMapCarPin.CarColor
            /// 0 at the start of the route, 1 at its end.
            let fraction: Double
        }

        let cars: [Car]
        /// How far the car in front has gone: the yellow part of the track.
        let leadFraction: Double
    }

    /// The track's cars, or `nil` until the trip and its route are known.
    var routeProgress: RouteProgress? { nil }

    /// Every participant: this phone's own car first, then the others in the order of the trip.
    var participantRows: [ParticipantRow] {
        guard let state else { return [] }
        return state.participants.compactMap { car in
            CarStatus(of: car).map {
                ParticipantRow(
                    status: $0,
                    timeToDestination: $0.lastSeenLine == nil ? carLookups[car.id]?.timeLeft : nil,
                    isMe: car.id == myParticipantID
                )
            }
        }
    }

    /// How long this car needs to reach its next stop, or `nil` until it is looked up.
    var timeToNextStop: Duration? { carLookups[myParticipantID]?.timeToNextStop }

    /// Looks up every car's street and arrival time once, at most every 30 seconds per car (see `LookUpCar`).
    func RefreshAllCars() async {
        for car in state?.participants ?? [] {
            await LookUpCar(car.id)
        }
    }

    /// Keeps every car's street and arrival time up to date while the list is on screen. The view runs this in a
    /// task, so it ends with the list. The cars are looked up one after the other, not at once, to stay within what
    /// Apple allows an app to ask of routing.
    func TrackAllCars() async {
        while Task.isCancelled == false {
            await RefreshAllCars()
            try? await Task.sleep(for: .seconds(Self.carLookupInterval))
        }
    }
}

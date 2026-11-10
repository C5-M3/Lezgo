//
//  TripMapViewModel+Types.swift
//  Lezgo
//
//  Created by Nathan Sudiara on 28/10/26.
//

import Foundation

// The trip map's small state types, nested in `TripMapViewModel` (ADR 0019), kept here so the view model file stays
// within SwiftLint's file length.
extension TripMapViewModel {
    /// How often a tapped car's street and time left are looked up again (`specs/UserStories.md` → US-06, "Data").
    static let carLookupInterval: TimeInterval = 30

    /// What is left of another member's way back to the group's road, drawn dashed in the colour of their robot.
    struct CarWayBack: Identifiable, Hashable {
        let id: UUID
        let path: [Coordinate]
        let carColor: TripMapCarPin.CarColor
    }

    /// What the trip map camera follows.
    enum CameraMode: Hashable {
        /// The camera stays on this phone's car as it moves.
        case followMyCar
        /// The camera shows the whole route; it no longer moves with the car.
        case wholeRoute
        /// The person moved the map by hand; the camera stays where they left it.
        case free
        /// The camera stays on a tapped car as it moves, while its status card is open.
        case followCar(UUID)
    }

    /// The confirmation shown before leaving the trip from the map (`specs/UserStories.md` → US-07, "Leave and end").
    enum LeaveConfirmation: Hashable {
        /// A member: "Exit trip?"
        case exitTrip
        /// The leader: "End trip?", or "End trip? Not everyone has arrived yet." when someone is still on the way.
        case endTrip(everyoneHasArrived: Bool)
    }

    /// Why the trip map closed on this phone, which then returns to Home, or to the Trip Room for `backToTripRoom`.
    enum CloseReason: Hashable {
        /// The leader planned a New Destination: the trip is back in `LOBBY` and every phone opens the Trip Room.
        case backToTripRoom
        /// This member chose "Exit Trip".
        case exited
        /// This leader chose "End Trip".
        case ended
        /// Another phone, the leader's, ended the trip: "The leader ended the trip."
        case endedByLeader
        /// The leader removed this member: "You were removed from the trip."
        case removed
    }

    /// What the bottom card shows once this phone's car has arrived (`specs/UserStories.md` → US-07, "Arrive").
    enum ArrivalCard: Hashable {
        /// "You have arrived" · "Waiting for everyone to arrive"
        case waitingForEveryone
        /// "Everyone has arrived!" (and, for the leader, "Continue your trip?")
        case everyoneArrived

        var title: LocalizedStringResource {
            switch self {
            case .waitingForEveryone: .tripMapYouHaveArrived
            case .everyoneArrived: .tripMapEveryoneHasArrived
            }
        }

        /// "Waiting for everyone to arrive", or "Continue your trip?" for the leader once everyone is there.
        func Subtitle(isLeader: Bool) -> LocalizedStringResource? {
            switch self {
            case .waitingForEveryone: .tripMapWaitingForEveryone
            case .everyoneArrived: isLeader ? .tripMapContinueYourTrip : nil
            }
        }
    }

    /// What was last looked up about a tapped car, and when.
    struct CarLookup {
        var street: String?
        var timeLeft: Duration?
        var lookedUpAt: Date
    }
}

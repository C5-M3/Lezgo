//
//  TripServiceError.swift
//  Lezgo
//
//  Created by Nathan Sudiara on 26/10/26.
//

import Foundation

/// Why a `TripService` call failed. Show `message` to the person; every case has a clear sentence.
enum TripServiceError: Error, Hashable {
    /// No internet connection, or iCloud could not be reached.
    case noNetwork
    /// The phone is not signed in to iCloud, which every trip member needs.
    case notSignedInToICloud
    /// No trip with this room code or ID.
    case notFound
    /// The trip is `ENDED` or `CANCELLED`, so it cannot be joined or changed.
    case tripEnded
    /// The trip is already on the road (`IN_TRIP`), and a started trip takes no new people (US-02).
    case tripAlreadyStarted
    /// Someone else changed the same thing first, for example two people picked a new leader at once.
    case conflict
    /// The action is not allowed for this person or in this trip status, for example a member removing someone.
    case notAllowed
    /// Another car in the trip already has this name (ignoring upper/lower case and spaces at the ends).
    case nameAlreadyUsed
    /// This iCloud account is already in another open trip (ADR 0031): one account is in one trip at a time.
    case alreadyInTrip

    var message: LocalizedStringResource {
        switch self {
        case .noNetwork: .tripServiceErrorNoNetwork
        case .notSignedInToICloud: .tripServiceErrorNotSignedInToICloud
        case .notFound: .tripServiceErrorNotFound
        case .tripEnded: .tripServiceErrorTripEnded
        case .tripAlreadyStarted: .tripServiceErrorTripAlreadyStarted
        case .conflict: .tripServiceErrorConflict
        case .notAllowed: .tripServiceErrorNotAllowed
        case .nameAlreadyUsed: .tripServiceErrorNameAlreadyUsed
        case .alreadyInTrip: .tripServiceErrorAlreadyInTrip
        }
    }
}

//
//  SiriHandoff.swift
//  Lezgo
//
//  Created by Nathan Sudiara on 13/11/26.
//

import Foundation
import Observation

/// What a Siri intent hands to Home inside the app (US-08, ADR 0030): the trip "Join a trip" joined, or the plan
/// link "Create a trip" made. Siri's `OpenURLIntent` refuses the app's own `lezgo://` links ("URL scheme is
/// unsupported"), so the intents bring the app to the front and leave their result here; Home takes it once.
@Observable
final class SiriHandoff {
    /// The one the app uses: Siri intents and Home share it.
    static let shared = SiriHandoff()

    /// A plan link waiting for Home; a newer one replaces it.
    private(set) var pendingLink: URL?
    /// A trip Siri joined, waiting for Home to open its Trip Room.
    private(set) var pendingJoin: TripSession?

    func Open(_ link: URL) {
        pendingLink = link
    }

    func Joined(_ session: TripSession) {
        pendingJoin = session
    }

    /// The waiting link, once.
    func TakeLink() -> URL? {
        defer { pendingLink = nil }
        return pendingLink
    }

    /// The joined trip, once.
    func TakeJoin() -> TripSession? {
        defer { pendingJoin = nil }
        return pendingJoin
    }
}

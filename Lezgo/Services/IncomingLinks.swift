//
//  IncomingLinks.swift
//  Lezgo
//
//  Created by Nathan Sudiara on 12/11/26.
//

import Foundation
import Observation

/// Links a Siri intent hands to Home inside the app (US-08). Siri's `OpenURLIntent` refuses the app's own `lezgo://`
/// links ("URL scheme is unsupported"), so "Join a trip" and "Create a trip" bring the app to the front and leave the
/// link here; Home takes it as if it had arrived through `onOpenURL`.
@Observable
final class IncomingLinks {
    /// The one the app uses: Siri intents and Home share it.
    static let shared = IncomingLinks()

    /// The link waiting for Home; a newer one replaces it.
    private(set) var pending: URL?

    func Open(_ link: URL) {
        pending = link
    }

    /// The waiting link, once: Home handles it, then it is gone.
    func Take() -> URL? {
        defer { pending = nil }
        return pending
    }
}

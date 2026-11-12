//
//  BackgroundLocationKeeper.swift
//  Lezgo
//
//  Created by Nathan Sudiara on 12/11/26.
//

import CoreLocation
import Foundation

/// A background location session: iOS shows the location arrow in the Dynamic Island while one is open.
/// `CLBackgroundActivitySession` is the real one; tests use a fake.
protocol BackgroundLocationSession: AnyObject {
    func Invalidate()
}

extension CLBackgroundActivitySession: BackgroundLocationSession {
    func Invalidate() {
        invalidate()
    }
}

/// Holds the background location session for `LiveLocationProvider` and makes sure it ends (#316).
///
/// iOS keeps a background session open until the app invalidates it. It does not end it when location access is
/// turned off, when the app is closed, or even when the app is deleted, so the location arrow stayed in the
/// Dynamic Island until the phone was restarted. The keeper therefore ends the session as soon as access is lost,
/// and `EndLeftover` ends one an earlier run of the app left open.
final class BackgroundLocationKeeper {
    private let makeSession: () -> any BackgroundLocationSession
    private var session: (any BackgroundLocationSession)?

    init(makeSession: @escaping () -> any BackgroundLocationSession = { CLBackgroundActivitySession() }) {
        self.makeSession = makeSession
    }

    /// Opens the session while access is allowed and ends it when access is lost. A new session can only start
    /// with the app on screen, which is where the person turns access back on.
    func Follow(isAccessAllowed: Bool) {
        if isAccessAllowed {
            guard session == nil else { return }
            session = makeSession()
        } else {
            Stop()
        }
    }

    func Stop() {
        session?.Invalidate()
        session = nil
    }

    /// Ends a session an earlier run of the app left open, for example when it was closed from the app switcher
    /// during a trip. iOS then starts the app again and hands the open session to the first one the app makes;
    /// nothing here shares the location at launch, so that session is ended at once. The trip map opens its own.
    static func EndLeftover(
        makeSession: () -> any BackgroundLocationSession = { CLBackgroundActivitySession() }
    ) {
        makeSession().Invalidate()
    }

    /// `false` when an update says location access is off for Lezgo, off for the whole phone, or restricted.
    static func IsAccessAllowed(denied: Bool, deniedGlobally: Bool, restricted: Bool) -> Bool {
        denied == false && deniedGlobally == false && restricted == false
    }
}

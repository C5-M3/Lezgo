//
//  BackgroundLocationKeeperTests.swift
//  LezgoTests
//
//  Created by Nathan Sudiara on 12/11/26.
//

import Testing
@testable import Lezgo

/// The background location session behind the Dynamic Island's location arrow (#316): kept only while access is
/// "While Using the App", and never left behind by an earlier run of the app.
struct BackgroundLocationKeeperTests {
    /// Counts the sessions made and invalidated, in place of `CLBackgroundActivitySession`.
    private final class SessionLog {
        var made: [FakeSession] = []

        func Make() -> any BackgroundLocationSession {
            let session = FakeSession()
            made.append(session)
            return session
        }
    }

    private final class FakeSession: BackgroundLocationSession {
        var invalidateCount = 0

        func Invalidate() {
            invalidateCount += 1
        }
    }

    @Test func AllowedAccessStartsOneSession() {
        let log = SessionLog()
        let keeper = BackgroundLocationKeeper(makeSession: log.Make)

        keeper.Follow(needsSession: true)
        keeper.Follow(needsSession: true)

        #expect(log.made.count == 1)
        #expect(log.made.first?.invalidateCount == 0)
    }

    @Test func LostAccessEndsTheSession() throws {
        let log = SessionLog()
        let keeper = BackgroundLocationKeeper(makeSession: log.Make)

        keeper.Follow(needsSession: true)
        keeper.Follow(needsSession: false)
        keeper.Follow(needsSession: false)

        let session = try #require(log.made.first)
        #expect(log.made.count == 1)
        #expect(session.invalidateCount == 1)
    }

    @Test func DeniedAccessFromTheStartMakesNoSession() {
        let log = SessionLog()
        let keeper = BackgroundLocationKeeper(makeSession: log.Make)

        keeper.Follow(needsSession: false)

        #expect(log.made.isEmpty)
    }

    @Test func RestoredAccessStartsANewSession() {
        let log = SessionLog()
        let keeper = BackgroundLocationKeeper(makeSession: log.Make)

        keeper.Follow(needsSession: true)
        keeper.Follow(needsSession: false)
        keeper.Follow(needsSession: true)

        #expect(log.made.count == 2)
        #expect(log.made.last?.invalidateCount == 0)
    }

    @Test func StopEndsTheSessionOnce() throws {
        let log = SessionLog()
        let keeper = BackgroundLocationKeeper(makeSession: log.Make)

        keeper.Follow(needsSession: true)
        keeper.Stop()
        keeper.Stop()

        let session = try #require(log.made.first)
        #expect(session.invalidateCount == 1)
    }

    @Test func LeftoverFromAnEarlierRunIsTakenOverAndEnded() throws {
        let log = SessionLog()

        BackgroundLocationKeeper.EndLeftover(makeSession: log.Make)

        let session = try #require(log.made.first)
        #expect(log.made.count == 1)
        #expect(session.invalidateCount == 1)
    }

    /// The access on one location update, and whether the background session is needed.
    struct AccessFlags: Sendable {
        var denied = false
        var deniedGlobally = false
        var restricted = false
        var isAlways = false
        var needsSession: Bool
    }

    @Test(arguments: [
        AccessFlags(needsSession: true),
        AccessFlags(denied: true, needsSession: false),
        AccessFlags(deniedGlobally: true, needsSession: false),
        AccessFlags(restricted: true, needsSession: false),
        AccessFlags(isAlways: true, needsSession: false)
    ])
    func SessionIsNeededOnlyWithWhenInUseAccess(flags: AccessFlags) {
        let needsSession = BackgroundLocationKeeper.NeedsSession(
            denied: flags.denied,
            deniedGlobally: flags.deniedGlobally,
            restricted: flags.restricted,
            isAuthorizedAlways: flags.isAlways
        )

        #expect(needsSession == flags.needsSession)
    }
}

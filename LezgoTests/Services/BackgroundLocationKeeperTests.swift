//
//  BackgroundLocationKeeperTests.swift
//  LezgoTests
//
//  Created by Nathan Sudiara on 12/11/26.
//

import Testing
@testable import Lezgo

/// The background location session behind the Dynamic Island's location arrow (#316): kept only while location
/// access is allowed, and never left behind by an earlier run of the app.
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

        keeper.Follow(isAccessAllowed: true)
        keeper.Follow(isAccessAllowed: true)

        #expect(log.made.count == 1)
        #expect(log.made.first?.invalidateCount == 0)
    }

    @Test func LostAccessEndsTheSession() throws {
        let log = SessionLog()
        let keeper = BackgroundLocationKeeper(makeSession: log.Make)

        keeper.Follow(isAccessAllowed: true)
        keeper.Follow(isAccessAllowed: false)
        keeper.Follow(isAccessAllowed: false)

        let session = try #require(log.made.first)
        #expect(log.made.count == 1)
        #expect(session.invalidateCount == 1)
    }

    @Test func DeniedAccessFromTheStartMakesNoSession() {
        let log = SessionLog()
        let keeper = BackgroundLocationKeeper(makeSession: log.Make)

        keeper.Follow(isAccessAllowed: false)

        #expect(log.made.isEmpty)
    }

    @Test func RestoredAccessStartsANewSession() {
        let log = SessionLog()
        let keeper = BackgroundLocationKeeper(makeSession: log.Make)

        keeper.Follow(isAccessAllowed: true)
        keeper.Follow(isAccessAllowed: false)
        keeper.Follow(isAccessAllowed: true)

        #expect(log.made.count == 2)
        #expect(log.made.last?.invalidateCount == 0)
    }

    @Test func StopEndsTheSessionOnce() throws {
        let log = SessionLog()
        let keeper = BackgroundLocationKeeper(makeSession: log.Make)

        keeper.Follow(isAccessAllowed: true)
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

    @Test(arguments: [
        (denied: false, deniedGlobally: false, restricted: false, allowed: true),
        (denied: true, deniedGlobally: false, restricted: false, allowed: false),
        (denied: false, deniedGlobally: true, restricted: false, allowed: false),
        (denied: false, deniedGlobally: false, restricted: true, allowed: false)
    ])
    func AccessIsAllowedOnlyWhenNothingDeniesIt(
        flags: (denied: Bool, deniedGlobally: Bool, restricted: Bool, allowed: Bool)
    ) {
        let isAllowed = BackgroundLocationKeeper.IsAccessAllowed(
            denied: flags.denied,
            deniedGlobally: flags.deniedGlobally,
            restricted: flags.restricted
        )

        #expect(isAllowed == flags.allowed)
    }
}

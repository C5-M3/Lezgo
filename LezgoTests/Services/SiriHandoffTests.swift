//
//  SiriHandoffTests.swift
//  LezgoTests
//
//  Created by Nathan Sudiara on 13/11/26.
//

import Foundation
import Testing
@testable import Lezgo

/// What a Siri intent hands to Home inside the app (`specs/UserStories.md` → US-08): a trip "Join a trip" joined, or
/// the plan link "Create a trip" made. Siri cannot open the app's own `lezgo://` links.
@MainActor
struct SiriHandoffTests {
    @Test func OpenedLinkWaitsForHomeAndIsTakenOnce() throws {
        let handoff = SiriHandoff()
        let link = try #require(URL(string: "lezgo://plan?to=Malang"))

        handoff.Open(link)

        #expect(handoff.pendingLink == link)
        #expect(handoff.TakeLink() == link)
        #expect(handoff.TakeLink() == nil)
    }

    @Test func NewerLinkReplacesAnOlderOne() throws {
        let handoff = SiriHandoff()
        let older = try #require(URL(string: "lezgo://plan?to=Malang"))
        let newer = try #require(URL(string: "lezgo://plan?to=Batu"))

        handoff.Open(older)
        handoff.Open(newer)

        #expect(handoff.TakeLink() == newer)
    }

    @Test func JoinedTripWaitsForHomeAndIsTakenOnce() {
        let handoff = SiriHandoff()
        let session = TripSession(myParticipantID: TripFixtures.budiID, state: TripMapFixtures.State(status: .lobby))

        handoff.Joined(session)

        #expect(handoff.pendingJoin == session)
        #expect(handoff.TakeJoin() == session)
        #expect(handoff.TakeJoin() == nil)
    }
}

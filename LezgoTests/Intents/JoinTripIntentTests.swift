//
//  JoinTripIntentTests.swift
//  LezgoTests
//
//  Created by Nathan Sudiara on 12/11/26.
//

import Foundation
import Testing
@testable import Lezgo

/// The link "Join a trip" opens: the same one as an invite, so Home fills in the join dialog (US-02).
struct JoinTripIntentTests {
    @Test func JoinLinkIsAnInviteLinkWithTheCode() throws {
        let link = try #require(JoinTripIntent.JoinLink(roomCode: "897654"))

        #expect(link.absoluteString == "lezgo://join?code=897654")
        #expect(InviteLink.RoomCode(from: link) == "897654")
    }
}

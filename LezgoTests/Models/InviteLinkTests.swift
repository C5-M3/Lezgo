//
//  InviteLinkTests.swift
//  LezgoTests
//
//  Created by Oky Faishal on 30/10/26.
//

import Foundation
import Testing
@testable import Lezgo

/// The invite link (US-02, US-04, ADR 0020): built in the Trip Room, read back when it opens the app.
struct InviteLinkTests {
    @Test func InviteLinkIsAUniversalLinkWithTheRoomCode() {
        let url = InviteLink.Make(roomCode: "897654")

        #expect(url?.absoluteString == "https://lezgo-trip.netlify.app/join?code=897654")
    }

    @Test(arguments: [
        "https://lezgo-trip.netlify.app/join?code=897654",
        "https://lezgo-trip.netlify.app/join/?code=897654",
        "https://LEZGO-TRIP.netlify.app/join?code=897654",
        "lezgo://join?code=897654"
    ])
    func OpeningAnInviteLinkGivesTheRoomCode(link: String) throws {
        let url = try #require(URL(string: link))

        #expect(InviteLink.RoomCode(from: url) == "897654")
    }

    @Test(arguments: [
        "https://lezgo-trip.netlify.app/join",
        "https://lezgo-trip.netlify.app/join?code=",
        "https://lezgo-trip.netlify.app/join?code=8976",
        "https://lezgo-trip.netlify.app/join?code=8976543",
        "https://lezgo-trip.netlify.app/join?code=89a654",
        "https://lezgo-trip.netlify.app/join?code=%D9%A8%D9%A9%D9%A7%D9%A6%D9%A5%D9%A4",
        "https://lezgo-trip.netlify.app/other?code=897654",
        "https://example.com/join?code=897654",
        "http://lezgo-trip.netlify.app/join?code=897654",
        "lezgo://other?code=897654",
        "mailto:someone@example.com"
    ])
    func OtherLinksGiveNoRoomCode(link: String) throws {
        let url = try #require(URL(string: link))

        #expect(InviteLink.RoomCode(from: url) == nil)
    }
}

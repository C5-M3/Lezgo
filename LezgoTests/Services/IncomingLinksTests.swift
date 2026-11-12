//
//  IncomingLinksTests.swift
//  LezgoTests
//
//  Created by Nathan Sudiara on 12/11/26.
//

import Foundation
import Testing
@testable import Lezgo

/// Links a Siri intent hands to Home inside the app (`specs/UserStories.md` → US-08). Siri cannot open the app's own
/// `lezgo://` links, so "Join a trip" and "Create a trip" pass them here instead.
@MainActor
struct IncomingLinksTests {
    @Test func OpenedLinkWaitsForHome() throws {
        let links = IncomingLinks()
        let link = try #require(URL(string: "lezgo://join?code=897654"))

        links.Open(link)

        #expect(links.pending == link)
    }

    @Test func TakingTheLinkClearsIt() throws {
        let links = IncomingLinks()
        let link = try #require(URL(string: "lezgo://plan?to=Malang"))
        links.Open(link)

        #expect(links.Take() == link)
        #expect(links.pending == nil)
        #expect(links.Take() == nil)
    }

    @Test func NewerLinkReplacesAnOlderOne() throws {
        let links = IncomingLinks()
        let older = try #require(URL(string: "lezgo://join?code=111111"))
        let newer = try #require(URL(string: "lezgo://join?code=222222"))

        links.Open(older)
        links.Open(newer)

        #expect(links.Take() == newer)
    }
}

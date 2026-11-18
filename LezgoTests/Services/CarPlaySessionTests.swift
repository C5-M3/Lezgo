//
//  CarPlaySessionTests.swift
//  LezgoTests
//
//  Created by Oky Faishal on 18/11/26.
//

import Testing
@testable import Lezgo

/// Whether CarPlay is connected, which makes the phone show the On the Go list instead of the map (ADR 0034).
struct CarPlaySessionTests {
    @Test func NotConnectedAtFirst() {
        #expect(CarPlaySession().isConnected == false)
    }

    @Test func ConnectingMarksItConnected() {
        let session = CarPlaySession()

        session.Connected()

        #expect(session.isConnected)
    }

    @Test func DisconnectingClearsIt() {
        let session = CarPlaySession()
        session.Connected()

        session.Disconnected()

        #expect(session.isConnected == false)
    }
}

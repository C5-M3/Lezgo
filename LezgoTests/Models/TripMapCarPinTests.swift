//
//  TripMapCarPinTests.swift
//  LezgoTests
//
//  Created by Nathan Sudiara on 09/11/26.
//

import Foundation
import Testing
@testable import Lezgo

/// The name under a robot on the map: the driver's name, and "You" under this phone's own car.
struct TripMapCarPinTests {
    private func Pin(name: String, isMe: Bool) -> TripMapCarPin {
        TripMapCarPin(
            id: UUID(),
            displayName: name,
            coordinate: Coordinate(latitude: -7.27, longitude: 112.73),
            motionState: .driving,
            isLeader: false,
            isMe: isMe,
            isOffline: false
        )
    }

    @Test func OtherCarsShowTheirDriversName() {
        #expect(Pin(name: "Budi", isMe: false).label == "Budi")
    }

    @Test func MyOwnCarSaysYou() {
        #expect(Pin(name: "Budi", isMe: true).label == "You")
    }
}

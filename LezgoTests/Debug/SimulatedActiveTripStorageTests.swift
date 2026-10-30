//
//  SimulatedActiveTripStorageTests.swift
//  LezgoTests
//
//  Created by Oky Faishal on 29/10/26.
//

#if DEBUG
import Foundation
import Testing
@testable import Lezgo

/// The storage simulated screens use, so trying Exit there never clears the trip saved on the phone.
struct SimulatedActiveTripStorageTests {
    private let summary = ActiveTripSummary(
        tripID: SampleTrip.tripID,
        myParticipantID: SampleTrip.budiID,
        roomCode: "897654",
        startName: "Tunjungan Plaza",
        destinationName: "Pakuwon mall"
    )

    @Test func StartsWithTheGivenTrip() {
        let storage = SimulatedActiveTripStorage(summary: summary)

        #expect(storage.LoadActiveTrip() == summary)
    }

    @Test func KeepsASavedTrip() {
        let storage = SimulatedActiveTripStorage()

        storage.SaveActiveTrip(summary)

        #expect(storage.LoadActiveTrip() == summary)
    }

    @Test func ClearingForgetsTheTrip() {
        let storage = SimulatedActiveTripStorage(summary: summary)

        storage.ClearActiveTrip()

        #expect(storage.LoadActiveTrip() == nil)
    }
}
#endif

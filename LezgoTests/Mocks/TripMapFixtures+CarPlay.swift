//
//  TripMapFixtures+CarPlay.swift
//  LezgoTests
//
//  Created by Nathan Sudiara on 09/11/26.
//

import Foundation
@testable import Lezgo

/// A trip map and the CarPlay view model mirroring it, shared by the CarPlay tests.
extension TripMapFixtures {
    static func TripMap(
        me: UUID = budiID,
        states: [TripState],
        service: MockTripService? = nil,
        guidance: TripMapGuidance = Guidance()
    ) -> TripMapViewModel {
        TripMapViewModel(
            tripID: tripID,
            myParticipantID: me,
            tripService: service ?? MockTripService(states: states),
            navigator: MockTripMapNavigator(results: [.success(guidance)]),
            streetNameService: MockStreetNameService(),
            clock: { now }
        )
    }

    /// A CarPlay view model mirroring `tripMap`, after the trip map has read every state.
    static func CarPlay(
        mirroring tripMap: TripMapViewModel,
        on activeTripMap: ActiveTripMap = ActiveTripMap()
    ) async -> CarPlayTripViewModel {
        activeTripMap.Show(tripMap)
        await tripMap.Start()
        return CarPlayTripViewModel(activeTripMap: activeTripMap)
    }

    /// Agus and Budi at the destination, Citra `citraMetres` away from it.
    static func ArrivedState(citraMetres: Double) -> TripState {
        State(cars: [
            CarNearDestination(id: agusID, name: "Agus", metres: 5),
            CarNearDestination(id: budiID, name: "Budi", metres: 10),
            CarNearDestination(id: citraID, name: "Citra", metres: citraMetres)
        ])
    }
}

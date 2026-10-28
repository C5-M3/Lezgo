//
//  SimulatedTripRoomScreen.swift
//  Lezgo
//
//  Created by Oky Faishal on 28/10/26.
//

#if DEBUG
import SwiftUI

/// The Trip Room lobby on the sample trip, for `DebugScreen`.
struct SimulatedTripRoomScreen: View {
    let myParticipantID: UUID
    @State private var tripService: InMemoryTripService

    init(myParticipantID: UUID) {
        self.myParticipantID = myParticipantID
        _tripService = State(initialValue: SampleTrip.Service(status: .lobby, me: myParticipantID))
    }

    var body: some View {
        TripRoomView(tripID: SampleTrip.tripID, myParticipantID: myParticipantID)
            .environment(\.tripService, tripService)
    }
}

#Preview("Leader") {
    SimulatedTripRoomScreen(myParticipantID: SampleTrip.agusID)
}

#Preview("Member") {
    SimulatedTripRoomScreen(myParticipantID: SampleTrip.budiID)
}
#endif

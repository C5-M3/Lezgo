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

    /// - Parameter failure: when set, every save fails with this error, to check the error alerts.
    init(myParticipantID: UUID, failure: TripServiceError? = nil) {
        self.myParticipantID = myParticipantID
        let service = SampleTrip.Service(status: .lobby, me: myParticipantID)
        service.simulatedFailure = failure
        _tripService = State(initialValue: service)
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

#Preview("Leader offline") {
    SimulatedTripRoomScreen(myParticipantID: SampleTrip.agusID, failure: .noNetwork)
}
#endif

//
//  SimulatedTripMapScreen.swift
//  Lezgo
//
//  Created by Nathan Sudiara on 27/10/26.
//

#if DEBUG
import SwiftUI

/// The trip map on the sample trip, with `SimulatedDrive` moving the cars, for previews and `DebugScreen`.
struct SimulatedTripMapScreen: View {
    let myParticipantID: UUID
    /// How far into the drive to start; a large value starts with the cars at the destination.
    let startSecond: Int
    @State private var tripService: InMemoryTripService

    init(myParticipantID: UUID, startSecond: Int = 0) {
        self.myParticipantID = myParticipantID
        self.startSecond = startSecond
        _tripService = State(initialValue: SampleTrip.Service(status: .inTrip, me: myParticipantID))
    }

    var body: some View {
        TripMapView(
            viewModel: TripMapViewModel(
                tripID: SampleTrip.tripID,
                myParticipantID: myParticipantID,
                tripService: tripService,
                navigator: SimulatedTripMapNavigator()
            ),
            onNewDestination: {}
        )
        .task {
            await SimulatedDrive(tripService: tripService, startSecond: startSecond).Run()
        }
    }
}

#Preview("Leader") {
    SimulatedTripMapScreen(myParticipantID: SampleTrip.agusID)
}

#Preview("Member") {
    SimulatedTripMapScreen(myParticipantID: SampleTrip.budiID)
}

#Preview("Leader arrived") {
    SimulatedTripMapScreen(myParticipantID: SampleTrip.agusID, startSecond: 2_000)
}

#Preview("Member, largest text") {
    SimulatedTripMapScreen(myParticipantID: SampleTrip.budiID)
        .dynamicTypeSize(.accessibility5)
}

#Preview("Member, dark") {
    SimulatedTripMapScreen(myParticipantID: SampleTrip.budiID)
        .preferredColorScheme(.dark)
}
#endif

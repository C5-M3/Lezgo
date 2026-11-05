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
    /// Budi drives beside the route, to show the formation alerts.
    let budiLeavesRoute: Bool
    /// Budi stops on the road, to show the "has stopped" banner.
    let budiStops: Bool
    @State private var tripService: InMemoryTripService

    init(myParticipantID: UUID, startSecond: Int = 0, budiLeavesRoute: Bool = false, budiStops: Bool = false) {
        self.myParticipantID = myParticipantID
        self.startSecond = startSecond
        self.budiLeavesRoute = budiLeavesRoute
        self.budiStops = budiStops
        _tripService = State(initialValue: SampleTrip.Service(status: .inTrip, me: myParticipantID))
    }

    var body: some View {
        TripMapView(
            viewModel: TripMapViewModel(
                tripID: SampleTrip.tripID,
                myParticipantID: myParticipantID,
                tripService: tripService,
                navigator: SimulatedTripMapNavigator(),
                streetNameService: LiveStreetNameService()
            ),
            onReturnToTripRoom: { _ in }
        )
        .task {
            await SimulatedDrive(
                tripService: tripService,
                startSecond: startSecond,
                budiLeavesRoute: budiLeavesRoute,
                budiStops: budiStops
            ).Run()
        }
    }
}

#Preview("Leader") {
    SimulatedTripMapScreen(myParticipantID: SampleTrip.agusID)
}

#Preview("Member") {
    SimulatedTripMapScreen(myParticipantID: SampleTrip.budiID)
}

#Preview("Member off route") {
    SimulatedTripMapScreen(myParticipantID: SampleTrip.budiID, budiLeavesRoute: true)
}

#Preview("Leader sees a member off route") {
    SimulatedTripMapScreen(myParticipantID: SampleTrip.agusID, budiLeavesRoute: true)
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

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
    let leaderEndsTrip: Bool
    @State private var tripService: InMemoryTripService
    @State private var isShowingMap = false

    /// - Parameters:
    ///   - failure: when set, every save fails with this error, to check the error alerts.
    ///   - leaderEndsTrip: when `true`, the leader exits the room on another phone after 1 second.
    init(myParticipantID: UUID, failure: TripServiceError? = nil, leaderEndsTrip: Bool = false) {
        self.myParticipantID = myParticipantID
        self.leaderEndsTrip = leaderEndsTrip
        let service = SampleTrip.Service(status: .lobby, me: myParticipantID)
        service.simulatedFailure = failure
        _tripService = State(initialValue: service)
    }

    var body: some View {
        TripRoomView(
            tripID: SampleTrip.tripID,
            myParticipantID: myParticipantID,
            activeTripStorage: SimulatedActiveTripStorage(),
            onTripStarted: { isShowingMap = true }
        )
        .environment(\.tripService, tripService)
        .task { await EndTripAsLeader() }
        .fullScreenCover(isPresented: $isShowingMap) {
            TripMapView(
                viewModel: TripMapViewModel(
                    tripID: SampleTrip.tripID,
                    myParticipantID: myParticipantID,
                    tripService: tripService,
                    navigator: SimulatedTripMapNavigator(),
                    streetNameService: LiveStreetNameService()
                ),
                onNewDestination: {},
                onClose: { isShowingMap = false }
            )
        }
    }

    private func EndTripAsLeader() async {
        guard leaderEndsTrip else { return }
        // A short wait so the room is on screen before the leader leaves, as on a real second phone.
        try? await Task.sleep(for: .seconds(1))
        try? await tripService.EndTrip(tripID: SampleTrip.tripID, by: SampleTrip.agusID)
    }
}

#Preview("Leader") {
    SimulatedTripRoomScreen(myParticipantID: SampleTrip.agusID)
}

#Preview("Member") {
    SimulatedTripRoomScreen(myParticipantID: SampleTrip.budiID)
}

#Preview("Leader ends the trip") {
    SimulatedTripRoomScreen(myParticipantID: SampleTrip.budiID, leaderEndsTrip: true)
}

#Preview("Leader offline") {
    SimulatedTripRoomScreen(myParticipantID: SampleTrip.agusID, failure: .noNetwork)
}
#endif

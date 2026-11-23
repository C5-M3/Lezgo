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
    /// Agus's phone has been silent for 6 minutes.
    let agusIsOffline: Bool
    /// Agus gets a new route on the way.
    let agusChangesRoute: SimulatedDrive.RouteChange?
    /// Pretends CarPlay is connected, so the phone shows the On the Go list (ADR 0034).
    let carPlayConnected: Bool
    /// The leader started the trip alone (US-05, "Leader alone"): every member is removed before the drive.
    let isAlone: Bool
    @State private var tripService: InMemoryTripService

    init(
        myParticipantID: UUID,
        startSecond: Int = 0,
        budiLeavesRoute: Bool = false,
        budiStops: Bool = false,
        agusIsOffline: Bool = false,
        agusChangesRoute: SimulatedDrive.RouteChange? = nil,
        carPlayConnected: Bool = false,
        isAlone: Bool = false
    ) {
        self.myParticipantID = myParticipantID
        self.startSecond = startSecond
        self.budiLeavesRoute = budiLeavesRoute
        self.budiStops = budiStops
        self.agusIsOffline = agusIsOffline
        self.agusChangesRoute = agusChangesRoute
        self.carPlayConnected = carPlayConnected
        self.isAlone = isAlone
        _tripService = State(initialValue: SampleTrip.Service(status: .inTrip, me: myParticipantID))
    }

    var body: some View {
        TripMapView(viewModel: MakeViewModel(), onReturnToTripRoom: { _ in })
        .onAppear { if carPlayConnected { CarPlaySession.shared.Connected() } }
        .onDisappear { CarPlaySession.shared.Disconnected() }
        .task {
            if isAlone { await RemoveMembers() }
            await SimulatedDrive(
                tripService: tripService,
                startSecond: startSecond,
                budiLeavesRoute: budiLeavesRoute,
                budiStops: budiStops,
                agusIsOffline: agusIsOffline,
                agusChangesRoute: agusChangesRoute
            ).Run()
        }
    }

    private func RemoveMembers() async {
        let members = SampleTrip.State(status: .inTrip).participants.map(\.id).filter { $0 != SampleTrip.agusID }
        try? await tripService.RemoveParticipants(members, tripID: SampleTrip.tripID, by: SampleTrip.agusID)
    }

    /// The simulated drive speaks like a real trip, so voice guidance can be heard on a phone without other cars.
    /// Xcode previews stay silent.
    private func MakeViewModel() -> TripMapViewModel {
        let viewModel = TripMapViewModel(
            tripID: SampleTrip.tripID,
            myParticipantID: myParticipantID,
            tripService: tripService,
            navigator: SimulatedTripMapNavigator(),
            streetNameService: LiveStreetNameService()
        )
        if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] != "1" {
            viewModel.sound = TripMapSound(speaker: LiveNavigationSpeaker())
        }
        return viewModel
    }
}

private func ConnectedCarPlaySession() -> CarPlaySession {
    let session = CarPlaySession()
    session.Connected()
    return session
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

#Preview("Leader, CarPlay connected") {
    SimulatedTripMapScreen(myParticipantID: SampleTrip.agusID)
        .environment(\.carPlaySession, ConnectedCarPlaySession())
}

#Preview("Member, CarPlay connected") {
    SimulatedTripMapScreen(myParticipantID: SampleTrip.budiID)
        .environment(\.carPlaySession, ConnectedCarPlaySession())
}

#Preview("Member, dark") {
    SimulatedTripMapScreen(myParticipantID: SampleTrip.budiID)
        .preferredColorScheme(.dark)
}
#endif

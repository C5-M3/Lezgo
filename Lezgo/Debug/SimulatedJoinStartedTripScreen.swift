//
//  SimulatedJoinStartedTripScreen.swift
//  Lezgo
//

#if DEBUG
import SwiftUI

/// The room code sheet on a phone that is not in the sample trip, after entering the code of that trip while it is on
/// the road: the "Unable to join trip" dialog (US-02).
struct SimulatedJoinStartedTripScreen: View {
    @State private var viewModel: JoinTripViewModel?
    @State private var service: InMemoryTripService?

    var body: some View {
        Color.black
            .ignoresSafeArea()
            .sheet(isPresented: .constant(viewModel != nil)) {
                if let viewModel, let service {
                    JoinTripView(isPresented: .constant(true), viewModel: viewModel)
                        .environment(\.tripService, service)
                }
            }
            .task { await Prepare() }
    }

    private func Prepare() async {
        let store = InMemoryTripStore(trips: [SampleTrip.State(status: .inTrip)])
        let stranger = InMemoryTripService(store: store, userRecordID: "_stranger")
        let joinViewModel = JoinTripViewModel(
            roomCode: SampleTrip.roomCode,
            tripService: stranger,
            storage: SimulatedActiveTripStorage()
        )
        service = stranger
        viewModel = joinViewModel
        await joinViewModel.submitCode()
    }
}

#Preview("Join a trip that started") {
    SimulatedJoinStartedTripScreen()
}
#endif

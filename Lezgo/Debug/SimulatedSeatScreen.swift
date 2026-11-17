//
//  SimulatedSeatScreen.swift
//  Lezgo
//
//  Created by Oky Faishal on 16/11/26.
//

#if DEBUG
import SwiftUI

/// Two phones of Agus's iCloud account on one in-memory store with the sample trip (ADR 0031): `mine` is the phone
/// on screen, `other` is the second phone that takes the trip over.
@MainActor
struct SimulatedSeatPhones {
    let store: InMemoryTripStore
    let mine: InMemoryTripService
    let other: InMemoryTripService

    init(status: TripStatus, trips: [TripState]? = nil) {
        store = InMemoryTripStore(trips: trips ?? [SampleTrip.State(status: status)])
        let account = SampleTrip.UserRecordID(of: SampleTrip.agusID)
        mine = InMemoryTripService(store: store, userRecordID: account)
        other = InMemoryTripService(store: store, userRecordID: account)
    }

    /// `mine` takes the sample trip's seat, as when this phone opened the trip.
    func HoldTheSeat() async {
        _ = try? await mine.ResumeTrip(tripID: SampleTrip.tripID, participantID: SampleTrip.agusID)
    }

    /// The other phone continues the trip, so `mine` is told it was replaced.
    func TakeTheSeatOnTheOtherPhone() async {
        _ = try? await other.ResumeTrip(tripID: SampleTrip.tripID, participantID: SampleTrip.agusID)
    }
}

/// The Trip Room on `mine` until the other phone takes the trip over after 2 seconds, for `DebugScreen`.
struct SimulatedTakenOverRoomScreen: View {
    @State private var phones = SimulatedSeatPhones(status: .lobby)
    @State private var isReady = false

    var body: some View {
        ZStack {
            if isReady {
                TripRoomView(
                    tripID: SampleTrip.tripID,
                    myParticipantID: SampleTrip.agusID,
                    activeTripStorage: SimulatedActiveTripStorage()
                )
                .environment(\.tripService, phones.mine)
            }
        }
        .task {
            await phones.HoldTheSeat()
            isReady = true
            try? await Task.sleep(for: .seconds(2))
            await phones.TakeTheSeatOnTheOtherPhone()
        }
    }
}

/// The trip map on `mine` until the other phone takes the trip over after 2 seconds, for `DebugScreen`.
struct SimulatedTakenOverMapScreen: View {
    @State private var phones = SimulatedSeatPhones(status: .inTrip)
    @State private var isReady = false

    var body: some View {
        ZStack {
            if isReady {
                TripMapView(
                    viewModel: TripMapViewModel(
                        tripID: SampleTrip.tripID,
                        myParticipantID: SampleTrip.agusID,
                        tripService: phones.mine,
                        navigator: SimulatedTripMapNavigator(),
                        streetNameService: LiveStreetNameService(),
                        activeTripStorage: SimulatedActiveTripStorage()
                    ),
                    onReturnToTripRoom: { _ in }
                )
            }
        }
        .task {
            await phones.HoldTheSeat()
            isReady = true
            try? await Task.sleep(for: .seconds(2))
            await phones.TakeTheSeatOnTheOtherPhone()
        }
    }
}

/// Home on a phone that has no saved trip while the account's other phone is in the sample trip: Draft Trip shows,
/// and "Continue" asks before taking the trip over. The saved trip goes to this app's `UserDefaults`, so reinstall
/// the app afterwards.
struct SimulatedHomeFromAnotherPhoneScreen: View {
    @State private var phones = SimulatedSeatPhones(status: .lobby)
    @State private var isReady = false

    var body: some View {
        ZStack {
            if isReady {
                HomeView()
                    .environment(\.tripService, phones.mine)
            }
        }
        .task {
            await phones.TakeTheSeatOnTheOtherPhone()
            isReady = true
        }
    }
}

/// The room code sheet on a phone whose account is already in the sample trip, after entering another trip's code.
struct SimulatedJoinWhileInATripScreen: View {
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
        let store = InMemoryTripStore(trips: [SampleTrip.State(status: .lobby)])
        let mine = InMemoryTripService(store: store, userRecordID: SampleTrip.UserRecordID(of: SampleTrip.agusID))
        _ = try? await mine.ResumeTrip(tripID: SampleTrip.tripID, participantID: SampleTrip.agusID)
        let stranger = InMemoryTripService(store: store, userRecordID: "_stranger")
        guard let strangerTrip = try? await stranger.CreateTrip(plan: SampleTrip.plan, profile: nil) else { return }
        let joinViewModel = JoinTripViewModel(
            roomCode: strangerTrip.state.trip.roomCode,
            tripService: mine,
            storage: SimulatedActiveTripStorage()
        )
        service = mine
        viewModel = joinViewModel
        await joinViewModel.submitCode()
    }
}

#Preview("Room taken over") {
    SimulatedTakenOverRoomScreen()
}

#Preview("Map taken over") {
    SimulatedTakenOverMapScreen()
}

#Preview("Home, trip on another phone") {
    SimulatedHomeFromAnotherPhoneScreen()
}

#Preview("Join while in a trip") {
    SimulatedJoinWhileInATripScreen()
}
#endif

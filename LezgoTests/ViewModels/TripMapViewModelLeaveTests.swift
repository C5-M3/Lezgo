//
//  TripMapViewModelLeaveTests.swift
//  LezgoTests
//
//  Created by Nathan Sudiara on 27/10/26.
//

import Foundation
import Testing
@testable import Lezgo

/// Exit Trip, End Trip and the trip closing from another phone (`specs/UserStories.md` → US-07, "Leave and end").
struct TripMapViewModelLeaveTests {
    private typealias Fixtures = TripMapFixtures

    private func MakeViewModel(me: UUID, states: [TripState], service: MockTripService? = nil) -> TripMapViewModel {
        TripMapViewModel(
            tripID: Fixtures.tripID,
            myParticipantID: me,
            tripService: service ?? MockTripService(states: states),
            navigator: MockTripMapNavigator(results: [.success(Fixtures.Guidance())]),
            streetNameService: MockStreetNameService(),
            clock: { Fixtures.now }
        )
    }

    private func ArrivedState(citraMetres: Double) -> TripState {
        Fixtures.State(cars: [
            Fixtures.CarNearDestination(id: Fixtures.agusID, name: "Agus", metres: 5),
            Fixtures.CarNearDestination(id: Fixtures.budiID, name: "Budi", metres: 10),
            Fixtures.CarNearDestination(id: Fixtures.citraID, name: "Citra", metres: citraMetres)
        ])
    }

    // MARK: Asking

    @Test func MemberIsAskedToConfirmExit() async {
        let viewModel = MakeViewModel(me: Fixtures.budiID, states: [Fixtures.State()])
        await viewModel.Start()

        viewModel.RequestLeave()

        #expect(viewModel.leaveConfirmation == .exitTrip)
    }

    @Test func LeaderIsWarnedThatNotEveryoneHasArrived() async {
        let viewModel = MakeViewModel(me: Fixtures.agusID, states: [ArrivedState(citraMetres: 500)])
        await viewModel.Start()

        viewModel.RequestLeave()

        #expect(viewModel.leaveConfirmation == .endTrip(everyoneHasArrived: false))
    }

    @Test func LeaderAfterEveryoneArrivedIsAskedPlainly() async {
        let viewModel = MakeViewModel(me: Fixtures.agusID, states: [ArrivedState(citraMetres: 10)])
        await viewModel.Start()

        viewModel.RequestLeave()

        #expect(viewModel.leaveConfirmation == .endTrip(everyoneHasArrived: true))
    }

    @Test func CancelChangesNothing() async {
        let service = MockTripService(states: [Fixtures.State()])
        let viewModel = MakeViewModel(me: Fixtures.budiID, states: [], service: service)
        await viewModel.Start()

        viewModel.RequestLeave()
        viewModel.CancelLeave()

        #expect(viewModel.leaveConfirmation == nil)
        #expect(viewModel.closeReason == nil)
        #expect(service.exitedParticipantIDs.isEmpty)
    }

    // MARK: Confirming

    @Test func MemberExitsAndTheMapCloses() async {
        let service = MockTripService(states: [Fixtures.State()])
        let viewModel = MakeViewModel(me: Fixtures.budiID, states: [], service: service)
        await viewModel.Start()
        viewModel.RequestLeave()

        await viewModel.ConfirmLeave(.exitTrip)

        #expect(service.exitedParticipantIDs == [Fixtures.budiID])
        #expect(viewModel.closeReason == .exited)
        #expect(viewModel.leaveConfirmation == nil)
    }

    @Test func LeaderEndsTheTripForEveryone() async {
        let service = MockTripService(states: [Fixtures.State()])
        let viewModel = MakeViewModel(me: Fixtures.agusID, states: [], service: service)
        await viewModel.Start()
        viewModel.RequestLeave()

        await viewModel.ConfirmLeave(.endTrip(everyoneHasArrived: false))

        #expect(service.endedByLeaderIDs == [Fixtures.agusID])
        #expect(service.exitedParticipantIDs.isEmpty)
        #expect(viewModel.closeReason == .ended)
    }

    @Test func FailedExitKeepsTheMapOpenWithAMessage() async {
        let service = MockTripService(states: [Fixtures.State()])
        service.failure = .noNetwork
        let viewModel = MakeViewModel(me: Fixtures.budiID, states: [], service: service)
        await viewModel.Start()
        viewModel.RequestLeave()

        await viewModel.ConfirmLeave(.exitTrip)

        #expect(viewModel.closeReason == nil)
        #expect(viewModel.leaveErrorMessage == String(localized: TripServiceError.noNetwork.message))
    }

    @Test func DoubleTapOnConfirmLeavesOnce() async {
        let service = MockTripService(states: [Fixtures.State()])
        let viewModel = MakeViewModel(me: Fixtures.budiID, states: [], service: service)
        await viewModel.Start()
        viewModel.RequestLeave()

        async let first: Void = viewModel.ConfirmLeave(.exitTrip)
        async let second: Void = viewModel.ConfirmLeave(.exitTrip)
        _ = await (first, second)

        #expect(service.exitedParticipantIDs.count == 1)
    }

    /// The alert closes before its Confirm task runs, and closing it clears `leaveConfirmation`; the exit must
    /// still happen.
    @Test func ConfirmAfterTheAlertClosedStillExits() async {
        let service = MockTripService(states: [Fixtures.State()])
        let viewModel = MakeViewModel(me: Fixtures.budiID, states: [], service: service)
        await viewModel.Start()
        viewModel.RequestLeave()
        viewModel.CancelLeave()

        await viewModel.ConfirmLeave(.exitTrip)

        #expect(service.exitedParticipantIDs == [Fixtures.budiID])
        #expect(viewModel.closeReason == .exited)
    }

    /// The alert is closed while the request is on its way, so the red button can be tapped again.
    @Test func AskingAgainWhileLeavingDoesNothing() async {
        let service = MockTripService(states: [Fixtures.State()])
        let viewModel = MakeViewModel(me: Fixtures.budiID, states: [], service: service)
        var questionWhileLeaving: TripMapViewModel.LeaveConfirmation?
        service.whileLeaving = {
            viewModel.RequestLeave()
            questionWhileLeaving = viewModel.leaveConfirmation
        }
        await viewModel.Start()
        viewModel.RequestLeave()
        viewModel.CancelLeave()

        await viewModel.ConfirmLeave(.exitTrip)

        #expect(questionWhileLeaving == nil)
        #expect(viewModel.closeReason == .exited)
    }

    @Test func ErrorMessageCanBeDismissed() async {
        let service = MockTripService(states: [Fixtures.State()])
        service.failure = .noNetwork
        let viewModel = MakeViewModel(me: Fixtures.budiID, states: [], service: service)
        await viewModel.Start()
        viewModel.RequestLeave()
        await viewModel.ConfirmLeave(.exitTrip)

        viewModel.DismissLeaveError()

        #expect(viewModel.leaveErrorMessage == nil)
    }

    // MARK: Updates while leaving

    /// Leaves on purpose while the cloud already sends the result back, and returns the close reason the map had
    /// after it handled that update, before the request returned.
    private func CloseReasonWhileLeaving(
        me: UUID,
        update: TripState,
        confirmation: TripMapViewModel.LeaveConfirmation
    ) async -> TripMapViewModel.CloseReason? {
        let service = MockTripService(states: [Fixtures.State()])
        service.stateWhileLeaving = update
        let viewModel = MakeViewModel(me: me, states: [], service: service)
        var reasonWhileLeaving: TripMapViewModel.CloseReason?
        service.whileLeaving = {
            // Waiting for the update, not for a fixed time, so the check never runs before the map saw it.
            while viewModel.state != update { await Task.yield() }
            reasonWhileLeaving = viewModel.closeReason
        }
        let open = Task { await viewModel.Start() }
        while viewModel.isLoading { await Task.yield() }
        viewModel.RequestLeave()

        await viewModel.ConfirmLeave(confirmation)

        // Leaving finished, so the request really ran and the update above arrived while it was on its way.
        #expect(viewModel.closeReason == (confirmation == .exitTrip ? .exited : .ended))
        open.cancel()
        await open.value
        return reasonWhileLeaving
    }

    @Test(.timeLimit(.minutes(1)))
    func MemberExitingIsNotToldTheyWereRemoved() async {
        let update = Fixtures.State(cars: [
            Fixtures.Car(id: Fixtures.agusID, name: "Agus"),
            Fixtures.Car(id: Fixtures.citraID, name: "Citra")
        ])

        let reason = await CloseReasonWhileLeaving(me: Fixtures.budiID, update: update, confirmation: .exitTrip)

        #expect(reason == nil)
    }

    @Test(.timeLimit(.minutes(1)))
    func LeaderEndingIsNotToldTheLeaderEndedTheTrip() async {
        let update = Fixtures.State(status: .ended)

        let reason = await CloseReasonWhileLeaving(
            me: Fixtures.agusID,
            update: update,
            confirmation: .endTrip(everyoneHasArrived: true)
        )

        #expect(reason == nil)
    }

    /// The end request reached the cloud but failed on the way back, so only the update tells the leader it ended.
    @Test func LeaderSeeingTheirOwnEndedTripClosesWithoutAMessage() async {
        let viewModel = MakeViewModel(me: Fixtures.agusID, states: [Fixtures.State(), Fixtures.State(status: .ended)])

        await viewModel.Start()

        #expect(viewModel.closeReason == .ended)
    }

    // MARK: Closed from another phone

    @Test(arguments: [TripStatus.ended, .cancelled])
    func LeaderEndingTheTripClosesEveryMembersMap(status: TripStatus) async {
        let viewModel = MakeViewModel(me: Fixtures.budiID, states: [Fixtures.State(), Fixtures.State(status: status)])

        await viewModel.Start()

        #expect(viewModel.closeReason == .endedByLeader)
    }

    @Test func RemovedMemberIsTold() async {
        let withoutBudi = Fixtures.State(cars: [
            Fixtures.Car(id: Fixtures.agusID, name: "Agus"),
            Fixtures.Car(id: Fixtures.citraID, name: "Citra")
        ])
        let viewModel = MakeViewModel(me: Fixtures.budiID, states: [Fixtures.State(), withoutBudi])

        await viewModel.Start()

        #expect(viewModel.closeReason == .removed)
    }

    /// The member is looking at "Exit trip?" when the leader ends the trip: the question goes away, so the message
    /// that the leader ended the trip can show.
    @Test(.timeLimit(.minutes(1)))
    func TripClosedElsewhereClearsTheQuestion() async throws {
        let agus = SampleTrip.Service(status: .inTrip, me: SampleTrip.agusID)
        let viewModel = TripMapViewModel(
            tripID: SampleTrip.tripID,
            myParticipantID: SampleTrip.budiID,
            tripService: agus,
            navigator: MockTripMapNavigator(results: [.success(Fixtures.Guidance())]),
            streetNameService: MockStreetNameService()
        )
        let open = Task { await viewModel.Start() }
        while viewModel.isLoading { await Task.yield() }
        viewModel.RequestLeave()
        try #require(viewModel.leaveConfirmation == .exitTrip)

        try await agus.EndTrip(tripID: SampleTrip.tripID, by: SampleTrip.agusID)
        await open.value

        #expect(viewModel.closeReason == .endedByLeader)
        #expect(viewModel.leaveConfirmation == nil)
    }

    @Test(.timeLimit(.minutes(1)))
    func ClosingStopsFollowingTheTrip() async throws {
        let agus = SampleTrip.Service(status: .inTrip, me: SampleTrip.agusID)
        let viewModel = TripMapViewModel(
            tripID: SampleTrip.tripID,
            myParticipantID: SampleTrip.budiID,
            tripService: agus,
            navigator: MockTripMapNavigator(results: [.success(Fixtures.Guidance())]),
            streetNameService: MockStreetNameService()
        )
        let open = Task { await viewModel.Start() }
        try await Task.sleep(for: .milliseconds(20))

        try await agus.EndTrip(tripID: SampleTrip.tripID, by: SampleTrip.agusID)
        try await Task.sleep(for: .milliseconds(20))

        #expect(viewModel.closeReason == .endedByLeader)
        // Start returns by itself once the map closes, which also stops sharing the position.
        await open.value
    }
}

// MARK: - Active Trip Storage

extension TripMapViewModelLeaveTests {
    @Test func ConfirmLeaveExitTripClearsActiveTripStorage() async {
        let storage = FakeActiveTripStorage(initial: ActiveTripSummary(
            tripID: Fixtures.tripID,
            myParticipantID: Fixtures.budiID,
            roomCode: "123456",
            startName: "Start",
            destinationName: "End",
            memberNames: ["Budi"],
            status: .inTrip,
            isLeader: false
        ))
        let service = MockTripService(states: [Fixtures.State()])
        let viewModel = TripMapViewModel(
            tripID: Fixtures.tripID,
            myParticipantID: Fixtures.budiID,
            tripService: service,
            navigator: MockTripMapNavigator(results: [.success(Fixtures.Guidance())]),
            streetNameService: MockStreetNameService(),
            activeTripStorage: storage,
            clock: { Fixtures.now }
        )
        await viewModel.Start()
        await viewModel.ConfirmLeave(.exitTrip)

        #expect(viewModel.closeReason == .exited)
        #expect(storage.storedSummary == nil)
    }

    @Test func ConfirmLeaveEndTripClearsActiveTripStorage() async {
        let storage = FakeActiveTripStorage(initial: ActiveTripSummary(
            tripID: Fixtures.tripID,
            myParticipantID: Fixtures.agusID,
            roomCode: "123456",
            startName: "Start",
            destinationName: "End",
            memberNames: ["Agus"],
            status: .inTrip,
            isLeader: true
        ))
        let service = MockTripService(states: [Fixtures.State()])
        let viewModel = TripMapViewModel(
            tripID: Fixtures.tripID,
            myParticipantID: Fixtures.agusID,
            tripService: service,
            navigator: MockTripMapNavigator(results: [.success(Fixtures.Guidance())]),
            streetNameService: MockStreetNameService(),
            activeTripStorage: storage,
            clock: { Fixtures.now }
        )
        await viewModel.Start()
        await viewModel.ConfirmLeave(.endTrip(everyoneHasArrived: true))

        #expect(viewModel.closeReason == .ended)
        #expect(storage.storedSummary == nil)
    }
}

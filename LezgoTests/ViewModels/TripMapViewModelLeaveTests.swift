import Foundation
import Testing
@testable import Lezgo

/// Exit Trip, End Trip and the trip closing from another phone (`specs/UserStories.md` → US-07, "Leave and end").
struct TripMapViewModelLeaveTests {
    private typealias Fixtures = TripMapFixtures

    private func MakeViewModel(
        _ snapshots: [TripMapSnapshot],
        service: MockTripMapService? = nil
    ) -> TripMapViewModel {
        TripMapViewModel(
            tripID: Fixtures.tripID,
            service: service ?? MockTripMapService(snapshots: snapshots),
            navigator: MockTripMapNavigator(results: [.success(Fixtures.Guidance())]),
            clock: { Fixtures.now }
        )
    }

    private func ArrivedSnapshot(me: UUID, citraMetres: Double) -> TripMapSnapshot {
        Fixtures.Snapshot(me: me, cars: [
            Fixtures.CarNearDestination(id: Fixtures.agusID, name: "Agus", metres: 5),
            Fixtures.CarNearDestination(id: Fixtures.budiID, name: "Budi", metres: 10),
            Fixtures.CarNearDestination(id: Fixtures.citraID, name: "Citra", metres: citraMetres)
        ])
    }

    // MARK: Asking

    @Test func MemberIsAskedToConfirmExit() async {
        let viewModel = MakeViewModel([Fixtures.Snapshot(me: Fixtures.budiID)])
        await viewModel.Start()

        viewModel.RequestLeave()

        #expect(viewModel.leaveConfirmation == .exitTrip)
    }

    @Test func LeaderIsWarnedThatNotEveryoneHasArrived() async {
        let viewModel = MakeViewModel([ArrivedSnapshot(me: Fixtures.agusID, citraMetres: 500)])
        await viewModel.Start()

        viewModel.RequestLeave()

        #expect(viewModel.leaveConfirmation == .endTrip(everyoneHasArrived: false))
    }

    @Test func LeaderAfterEveryoneArrivedIsAskedPlainly() async {
        let viewModel = MakeViewModel([ArrivedSnapshot(me: Fixtures.agusID, citraMetres: 10)])
        await viewModel.Start()

        viewModel.RequestLeave()

        #expect(viewModel.leaveConfirmation == .endTrip(everyoneHasArrived: true))
    }

    @Test func CancelChangesNothing() async {
        let service = MockTripMapService(snapshots: [Fixtures.Snapshot(me: Fixtures.budiID)])
        let viewModel = MakeViewModel([], service: service)
        await viewModel.Start()

        viewModel.RequestLeave()
        viewModel.CancelLeave()

        #expect(viewModel.leaveConfirmation == nil)
        #expect(viewModel.closeReason == nil)
        #expect(service.exitedParticipantIDs.isEmpty)
    }

    // MARK: Confirming

    @Test func MemberExitsAndTheMapCloses() async {
        let service = MockTripMapService(snapshots: [Fixtures.Snapshot(me: Fixtures.budiID)])
        let viewModel = MakeViewModel([], service: service)
        await viewModel.Start()
        viewModel.RequestLeave()

        await viewModel.ConfirmLeave()

        #expect(service.exitedParticipantIDs == [Fixtures.budiID])
        #expect(viewModel.closeReason == .exited)
        #expect(viewModel.leaveConfirmation == nil)
    }

    @Test func LeaderEndsTheTripForEveryone() async {
        let service = MockTripMapService(snapshots: [Fixtures.Snapshot(me: Fixtures.agusID)])
        let viewModel = MakeViewModel([], service: service)
        await viewModel.Start()
        viewModel.RequestLeave()

        await viewModel.ConfirmLeave()

        #expect(service.endedByLeaderIDs == [Fixtures.agusID])
        #expect(service.exitedParticipantIDs.isEmpty)
        #expect(viewModel.closeReason == .ended)
    }

    @Test func FailedExitKeepsTheMapOpenWithAMessage() async {
        let service = MockTripMapService(snapshots: [Fixtures.Snapshot(me: Fixtures.budiID)])
        service.failure = .noNetwork
        let viewModel = MakeViewModel([], service: service)
        await viewModel.Start()
        viewModel.RequestLeave()

        await viewModel.ConfirmLeave()

        #expect(viewModel.closeReason == nil)
        #expect(viewModel.leaveErrorMessage == String(localized: TripServiceError.noNetwork.message))
    }

    @Test func DoubleTapOnConfirmLeavesOnce() async {
        let service = MockTripMapService(snapshots: [Fixtures.Snapshot(me: Fixtures.budiID)])
        let viewModel = MakeViewModel([], service: service)
        await viewModel.Start()
        viewModel.RequestLeave()

        async let first: Void = viewModel.ConfirmLeave()
        async let second: Void = viewModel.ConfirmLeave()
        _ = await (first, second)

        #expect(service.exitedParticipantIDs.count == 1)
    }

    @Test func ConfirmWithoutAskingDoesNothing() async {
        let service = MockTripMapService(snapshots: [Fixtures.Snapshot(me: Fixtures.budiID)])
        let viewModel = MakeViewModel([], service: service)
        await viewModel.Start()

        await viewModel.ConfirmLeave()

        #expect(service.exitedParticipantIDs.isEmpty)
        #expect(viewModel.closeReason == nil)
    }

    @Test func ErrorMessageCanBeDismissed() async {
        let service = MockTripMapService(snapshots: [Fixtures.Snapshot(me: Fixtures.budiID)])
        service.failure = .noNetwork
        let viewModel = MakeViewModel([], service: service)
        await viewModel.Start()
        viewModel.RequestLeave()
        await viewModel.ConfirmLeave()

        viewModel.DismissLeaveError()

        #expect(viewModel.leaveErrorMessage == nil)
    }

    // MARK: Closed from another phone

    @Test(arguments: [TripStatus.ended, .cancelled])
    func LeaderEndingTheTripClosesEveryMembersMap(status: TripStatus) async {
        let viewModel = MakeViewModel([
            Fixtures.Snapshot(me: Fixtures.budiID),
            Fixtures.Snapshot(me: Fixtures.budiID, status: status)
        ])

        await viewModel.Start()

        #expect(viewModel.closeReason == .endedByLeader)
    }

    @Test func RemovedMemberIsTold() async {
        let viewModel = MakeViewModel([
            Fixtures.Snapshot(me: Fixtures.budiID),
            Fixtures.Snapshot(me: Fixtures.budiID, memberIDs: [Fixtures.agusID, Fixtures.citraID])
        ])

        await viewModel.Start()

        #expect(viewModel.closeReason == .removed)
    }

    @Test(.timeLimit(.minutes(1)))
    func ClosingStopsFollowingTheTrip() async throws {
        let agus = SampleTrip.Service(status: .inTrip, me: SampleTrip.agusID)
        let viewModel = TripMapViewModel(
            tripID: SampleTrip.tripID,
            service: TripServiceMapAdapter(tripService: agus, myParticipantID: SampleTrip.budiID),
            navigator: MockTripMapNavigator(results: [.success(Fixtures.Guidance())])
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

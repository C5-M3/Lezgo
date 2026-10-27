import Foundation
import Testing
@testable import Lezgo

/// The arrival card on the trip map (`specs/UserStories.md` → US-07, "Arrive").
struct TripMapViewModelArrivalTests {
    private func MakeViewModel(snapshots: [TripMapSnapshot]) -> TripMapViewModel {
        TripMapViewModel(
            tripID: TripMapFixtures.tripID,
            service: MockTripMapService(snapshots: snapshots),
            navigator: MockTripMapNavigator(results: [.success(TripMapFixtures.Guidance())]),
            clock: { TripMapFixtures.now }
        )
    }

    private func ArrivalSnapshot(me: UUID, citraMetres: Double) -> TripMapSnapshot {
        TripMapFixtures.Snapshot(me: me, cars: [
            TripMapFixtures.CarNearDestination(id: TripMapFixtures.agusID, name: "Agus", metres: 5),
            TripMapFixtures.CarNearDestination(id: TripMapFixtures.budiID, name: "Budi", metres: 10),
            TripMapFixtures.CarNearDestination(id: TripMapFixtures.citraID, name: "Citra", metres: citraMetres)
        ])
    }

    @Test func NoArrivalCardOnTheWay() async {
        let viewModel = MakeViewModel(snapshots: [TripMapFixtures.Snapshot()])

        await viewModel.Start()

        #expect(viewModel.arrivalCard == nil)
    }

    @Test func MemberWhoArrivedFirstWaitsForEveryone() async {
        let viewModel = MakeViewModel(snapshots: [ArrivalSnapshot(me: TripMapFixtures.budiID, citraMetres: 500)])

        await viewModel.Start()

        #expect(viewModel.arrivalCard == .waitingForEveryone)
    }

    @Test func LeaderWhoArrivedBeforeEveryoneWaitsToo() async {
        let viewModel = MakeViewModel(snapshots: [ArrivalSnapshot(me: TripMapFixtures.agusID, citraMetres: 500)])

        await viewModel.Start()

        #expect(viewModel.arrivalCard == .waitingForEveryone)
        #expect(viewModel.isLeader)
    }

    @Test func EveryoneArrivedCard() async {
        let viewModel = MakeViewModel(snapshots: [ArrivalSnapshot(me: TripMapFixtures.agusID, citraMetres: 10)])

        await viewModel.Start()

        #expect(viewModel.arrivalCard == .everyoneArrived)
    }

    @Test func CardChangesWhenTheLastCarArrives() async {
        let viewModel = MakeViewModel(snapshots: [
            ArrivalSnapshot(me: TripMapFixtures.budiID, citraMetres: 500),
            ArrivalSnapshot(me: TripMapFixtures.budiID, citraMetres: 10)
        ])

        await viewModel.Start()

        #expect(viewModel.arrivalCard == .everyoneArrived)
    }
}

//
//  TripMapViewModelManualArrivalTests.swift
//  LezgoTests
//
//  Created by Nathan Sudiara on 07/11/26.
//

import Foundation
import Testing
@testable import Lezgo

/// "I've Arrived" on the trip map (`specs/UserStories.md` → US-07, "Arrive"): a driver near the destination whose
/// point is a little off says they have arrived, after a question that tells them how far the point is.
struct TripMapViewModelManualArrivalTests {
    private typealias Fixtures = TripMapFixtures

    private func MakeViewModel(
        me: UUID = Fixtures.budiID,
        budiMetres: Double,
        service: MockTripService? = nil,
        change: (inout Participant) -> Void = { _ in }
    ) -> (TripMapViewModel, MockTripService) {
        var budi = Fixtures.CarNearDestination(id: Fixtures.budiID, name: "Budi", metres: budiMetres)
        change(&budi)
        let state = Fixtures.State(cars: [
            Fixtures.CarNearDestination(id: Fixtures.agusID, name: "Agus", metres: budiMetres),
            budi
        ])
        let service = service ?? MockTripService(states: [state])
        let viewModel = TripMapViewModel(
            tripID: Fixtures.tripID,
            myParticipantID: me,
            tripService: service,
            navigator: MockTripMapNavigator(results: [.success(Fixtures.Guidance())]),
            streetNameService: MockStreetNameService(),
            clock: { Fixtures.now }
        )
        return (viewModel, service)
    }

    // MARK: The button

    @Test(arguments: [(metres: 200.0, shows: true), (999, true), (1_001, false), (5_000, false)])
    func ButtonShowsOnlyWithinOneKilometre(metres: Double, shows: Bool) async {
        let (viewModel, _) = MakeViewModel(budiMetres: metres)

        await viewModel.Start()

        #expect(viewModel.canMarkArrived == shows)
    }

    @Test func ButtonHidesOnceTheCarIsAtThePoint() async {
        let (viewModel, _) = MakeViewModel(budiMetres: 10)

        await viewModel.Start()

        #expect(viewModel.canMarkArrived == false)
    }

    @Test func ButtonHidesOnceTheDriverSaidTheyArrived() async {
        let (viewModel, _) = MakeViewModel(budiMetres: 200) { $0.arrivedAtWaypointID = Fixtures.destination.id }

        await viewModel.Start()

        #expect(viewModel.canMarkArrived == false)
    }

    @Test func TheLeaderHasTheButtonToo() async {
        let (viewModel, _) = MakeViewModel(me: Fixtures.agusID, budiMetres: 200)

        await viewModel.Start()

        #expect(viewModel.canMarkArrived)
    }

    // MARK: The question

    @Test func TappingItAsksWithTheDistanceToThePoint() async throws {
        let (viewModel, _) = MakeViewModel(budiMetres: 203)
        await viewModel.Start()

        viewModel.RequestMarkArrived()

        let confirmation = try #require(viewModel.manualArrival.confirmation)
        #expect(confirmation.destinationName == "Pakuwon mall")
        #expect(confirmation.distance == Measurement(value: 200, unit: .meters))
    }

    @Test func TappingItFarAwayAsksNothing() async {
        let (viewModel, _) = MakeViewModel(budiMetres: 5_000)
        await viewModel.Start()

        viewModel.RequestMarkArrived()

        #expect(viewModel.manualArrival.confirmation == nil)
    }

    @Test func CancelSavesNothing() async {
        let (viewModel, service) = MakeViewModel(budiMetres: 200)
        await viewModel.Start()
        viewModel.RequestMarkArrived()

        viewModel.manualArrival.Cancel()

        #expect(viewModel.manualArrival.confirmation == nil)
        #expect(service.markedArrivals.isEmpty)
    }

    @Test func ConfirmSavesTheArrivalAtTheDestination() async throws {
        let (viewModel, service) = MakeViewModel(budiMetres: 200)
        await viewModel.Start()
        viewModel.RequestMarkArrived()
        let confirmation = try #require(viewModel.manualArrival.confirmation)

        await viewModel.manualArrival.Confirm(confirmation)

        #expect(service.markedArrivals == [Fixtures.destination.id])
        #expect(viewModel.manualArrival.confirmation == nil)
        #expect(viewModel.manualArrival.errorMessage == nil)
    }

    @Test func FailedSaveShowsAMessageAndCanBeTriedAgain() async throws {
        let (viewModel, service) = MakeViewModel(budiMetres: 200)
        service.nextMarkArrivedFailure = .noNetwork
        await viewModel.Start()
        viewModel.RequestMarkArrived()
        let confirmation = try #require(viewModel.manualArrival.confirmation)

        await viewModel.manualArrival.Confirm(confirmation)

        #expect(viewModel.manualArrival.errorMessage == String(localized: TripServiceError.noNetwork.message))
        #expect(service.markedArrivals.isEmpty)

        viewModel.manualArrival.DismissError()
        #expect(viewModel.manualArrival.errorMessage == nil)
        #expect(viewModel.canMarkArrived)
    }
}

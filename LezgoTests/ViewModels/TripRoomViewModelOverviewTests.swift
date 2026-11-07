//
//  TripRoomViewModelOverviewTests.swift
//  LezgoTests
//
//  Created by oky faishal on 05/11/26.
//

import Foundation
import Testing
@testable import Lezgo

/// The map preview and "Overview" at the top of the Trip Room (`specs/UserStories.md` → US-04, "Room").
@MainActor
struct TripRoomViewModelOverviewTests {
    private func OpenRoom(_ state: TripState?) -> TripRoomViewModel {
        TripRoomViewModel(
            tripService: SampleTrip.Service(status: .lobby, me: SampleTrip.budiID),
            tripID: SampleTrip.tripID,
            myParticipantID: SampleTrip.budiID,
            initialState: state
        )
    }

    @Test func StopsCountOnlyTheCheckpoints() {
        // Tunjungan Plaza → Ciputra World → Pakuwon mall: one checkpoint between start and destination.
        #expect(OpenRoom(SampleTrip.State(status: .lobby)).numberOfStops == 1)
    }

    @Test func RouteWithoutCheckpointsHasNoStops() {
        var state = SampleTrip.State(status: .lobby)
        state.waypoints.removeAll { $0.kind == .checkpoint }

        #expect(OpenRoom(state).numberOfStops == 0)
    }

    @Test func OverviewNamesTheStartAndTheDestination() {
        let viewModel = OpenRoom(SampleTrip.State(status: .lobby))

        #expect(viewModel.startPoint?.name == "Tunjungan Plaza")
        #expect(viewModel.destination?.name == "Pakuwon mall")
    }

    @Test func PreviewFollowsTheSavedRoad() {
        let state = SampleTrip.State(status: .lobby)

        #expect(OpenRoom(state).routePolyline == state.route?.polyline)
    }

    @Test func PreviewIsEmptyUntilTheTripLoads() {
        let viewModel = OpenRoom(nil)

        #expect(viewModel.routePolyline.isEmpty)
        #expect(viewModel.destination == nil)
        #expect(viewModel.numberOfStops == 0)
    }
}

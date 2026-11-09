//
//  TripRoomViewModelEditRouteTests.swift
//  LezgoTests
//
//  Created by Oky Faishal on 09/11/26.
//

import Foundation
import Testing
@testable import Lezgo

/// "Edit" next to "Overview": the leader changes the route from the Trip Room (US-04, "Room").
@MainActor
struct TripRoomViewModelEditRouteTests {
    @Test func LeaderOpensThePlannerFromTheStartPointThroughTheCheckpointsToTheDestination() throws {
        let viewModel = MakeViewModel(me: SampleTrip.agusID)

        viewModel.RequestEditRoute()

        let planner = try #require(viewModel.editRoute)
        #expect(planner.purpose == .editRoute)
        #expect(planner.startingWaypoints.first?.kind == .start)
        #expect(planner.startingWaypoints.first?.name == viewModel.startPoint?.name)
        #expect(planner.startingWaypoints.last?.kind == .destination)
        #expect(planner.startingWaypoints.last?.name == viewModel.destination?.name)
        #expect(planner.startingWaypoints.count(where: { $0.kind == .checkpoint }) == viewModel.numberOfStops)
    }

    @Test func OnlyTheLeaderCanUseEdit() {
        let viewModel = MakeViewModel(me: SampleTrip.budiID)

        #expect(viewModel.canEditRoute == false)
        viewModel.RequestEditRoute()

        #expect(viewModel.editRoute == nil)
    }

    /// A double tap on "Edit" must not replace the planner the leader is already typing in.
    @Test func AskingTwiceKeepsTheSamePlanner() {
        let viewModel = MakeViewModel(me: SampleTrip.agusID)

        viewModel.RequestEditRoute()
        let first = viewModel.editRoute?.id
        viewModel.RequestEditRoute()

        #expect(first != nil)
        #expect(viewModel.editRoute?.id == first)
    }

    @Test func BackWithoutSavingClosesThePlannerAndChangesNothing() async throws {
        let service = SampleTrip.Service(status: .lobby, me: SampleTrip.agusID)
        let viewModel = MakeViewModel(me: SampleTrip.agusID, service: service)
        let before = try await service.FetchTrip(tripID: SampleTrip.tripID).trip.routeVersion
        viewModel.RequestEditRoute()

        viewModel.CloseEditRoute()

        #expect(viewModel.editRoute == nil)
        #expect(try await service.FetchTrip(tripID: SampleTrip.tripID).trip.routeVersion == before)
    }

    /// Save in the planner: the leader stays in the lobby and every phone shows the new destination.
    @Test func SavingShowsTheNewRouteOnEveryPhoneAndKeepsTheTripInTheLobby() async throws {
        let service = SampleTrip.Service(status: .lobby, me: SampleTrip.agusID)
        let leaderPhone = MakeViewModel(me: SampleTrip.agusID, service: service)
        let memberPhone = MakeViewModel(me: SampleTrip.budiID, service: service)
        let leaderListening = Task { await leaderPhone.Listen() }
        let memberListening = Task { await memberPhone.Listen() }
        defer {
            leaderListening.cancel()
            memberListening.cancel()
        }
        leaderPhone.RequestEditRoute()
        let planner = try #require(leaderPhone.editRoute)

        await planner.Save(TripPlanFixtures.ciputraToPakuwonCity)

        #expect(planner.didSave)
        try await WaitUntil {
            leaderPhone.destination?.name == "Pakuwon city mall" && memberPhone.destination?.name == "Pakuwon city mall"
        }
        #expect(memberPhone.tripStatus == .lobby)
        #expect(memberPhone.hasTripStarted == false)
    }

    /// The leader handed over the lead while the planner was open: it closes on that phone.
    @Test func HandingOverTheLeadClosesThePlanner() async throws {
        let service = SampleTrip.Service(status: .lobby, me: SampleTrip.agusID)
        let viewModel = MakeViewModel(me: SampleTrip.agusID, service: service)
        let listening = Task { await viewModel.Listen() }
        defer { listening.cancel() }
        try await WaitUntil { viewModel.state != nil }
        let budi = try #require(viewModel.participants.first(where: { $0.id == SampleTrip.budiID }))
        viewModel.RequestEditRoute()
        #expect(viewModel.editRoute != nil)

        await viewModel.HandOverLead(to: budi)

        try await WaitUntil { viewModel.editRoute == nil }
        #expect(viewModel.canEditRoute == false)
    }

    private func MakeViewModel(me participantID: UUID, service: InMemoryTripService? = nil) -> TripRoomViewModel {
        TripRoomViewModel(
            tripService: service ?? SampleTrip.Service(status: .lobby, me: participantID),
            tripID: SampleTrip.tripID,
            myParticipantID: participantID,
            initialState: SampleTrip.State(status: .lobby)
        )
    }

    private func WaitUntil(_ condition: () -> Bool) async throws {
        for _ in 0..<40 where !condition() {
            try await Task.sleep(for: .milliseconds(50))
        }
        #expect(condition())
    }
}

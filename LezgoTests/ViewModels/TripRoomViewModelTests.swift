import Foundation
import Testing
@testable import Lezgo

@MainActor
struct TripRoomViewModelTests {
    @Test func InitialStateDefaults() {
        let viewModel = TripRoomViewModel()

        #expect(!viewModel.originName.isEmpty)
        #expect(!viewModel.destinationName.isEmpty)
        #expect(viewModel.participants.isEmpty)
        #expect(viewModel.isCurrentUserLeader == true)
        #expect(viewModel.isSelectionMode == false)
        #expect(viewModel.tripStatus == .waiting)
    }

    @Test func StartTripUpdatesStatusWhenLeader() {
        let viewModel = TripRoomViewModel(isCurrentUserLeader: true)

        viewModel.StartTrip()

        #expect(viewModel.tripStatus == .inTrip)
    }

    @Test func StartTripDoesNothingWhenNotLeader() {
        let viewModel = TripRoomViewModel(isCurrentUserLeader: false)

        viewModel.StartTrip()

        #expect(viewModel.tripStatus == .waiting)
    }

    @Test func ToggleSelectionModeTogglesFlag() {
        let viewModel = TripRoomViewModel()

        #expect(viewModel.isSelectionMode == false)
        viewModel.ToggleSelectionMode()
        #expect(viewModel.isSelectionMode == true)
        viewModel.ToggleSelectionMode()
        #expect(viewModel.isSelectionMode == false)
    }

    @Test func SetLeaderTransfersCrownToSelectedParticipant() {
        let p1 = Participant(name: "Leader 1", description: "Car 1", isLeader: true)
        let p2 = Participant(name: "Member 2", description: "Car 2", isLeader: false)
        let viewModel = TripRoomViewModel(participants: [p1, p2], isCurrentUserLeader: true)

        viewModel.SetLeader(to: p2)

        #expect(viewModel.participants[0].isLeader == false)
        #expect(viewModel.participants[1].isLeader == true)
        #expect(viewModel.isCurrentUserLeader == false)
    }

    @Test func SetLeaderWithNonMemberLeavesStateUnchanged() {
        let p1 = Participant(name: "Leader 1", description: "Car 1", isLeader: true)
        let p2 = Participant(name: "Member 2", description: "Car 2", isLeader: false)
        let nonMember = Participant(name: "Non Member", description: "Car 99", isLeader: false)
        let viewModel = TripRoomViewModel(participants: [p1, p2], isCurrentUserLeader: true)

        viewModel.SetLeader(to: nonMember)

        #expect(viewModel.participants[0].isLeader == true)
        #expect(viewModel.participants[1].isLeader == false)
        #expect(viewModel.isCurrentUserLeader == true)
    }

    @Test func LeaveRoomSetsStatusToCancelled() {
        let viewModel = TripRoomViewModel()

        viewModel.LeaveRoom()

        #expect(viewModel.tripStatus == .cancelled)
    }

    @Test func RouteStopsDefaultsIncludeStartCheckpointAndDestination() {
        let viewModel = TripRoomViewModel()

        #expect(viewModel.routeStops.count >= 3)
        #expect(viewModel.routeStops.first?.kind == .start)
        #expect(viewModel.routeStops.contains(where: { $0.kind == .checkpoint }))
        #expect(viewModel.routeStops.last?.kind == .destination)
        #expect(viewModel.originName == viewModel.routeStops.first?.name)
        #expect(viewModel.destinationName == viewModel.routeStops.last?.name)
    }

    @Test func RouteStopsCanBeInitializedWithMultipleCheckpoints() {
        let stops: [TripRoomViewModel.RouteStop] = [
            .init(name: "Rumah", kind: .start),
            .init(name: "SPBU KM 19", kind: .checkpoint),
            .init(name: "Rest Area KM 57", kind: .checkpoint),
            .init(name: "Hotel Bandung", kind: .destination)
        ]
        let viewModel = TripRoomViewModel(routeStops: stops)

        #expect(viewModel.routeStops.count == 4)
        #expect(viewModel.routeStops.filter({ $0.kind == .checkpoint }).count == 2)
        #expect(viewModel.originName == "Rumah")
        #expect(viewModel.destinationName == "Hotel Bandung")
    }
}

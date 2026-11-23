//
//  HomeViewModelStopLocationTests.swift
//  LezgoTests
//
//  Created by Oky Faishal on 23/11/26.
//

import Foundation
import Testing
@testable import Lezgo

/// The first time Home opens without a trip, it makes sure no location use is left running from an earlier run.
@MainActor
struct HomeViewModelStopLocationTests {
    private final class StopCounter {
        private(set) var stops = 0
        func Stop() { stops += 1 }
    }

    private func MakeViewModel(counter: StopCounter) -> HomeViewModel {
        HomeViewModel(
            mapService: MockMapService(),
            searchService: MockLocationSearchService(),
            activeTripStorage: FakeActiveTripStorage(),
            stopsLeftoverLocation: counter.Stop
        )
    }

    private func MakePhone(store: InMemoryTripStore = InMemoryTripStore()) -> InMemoryTripService {
        InMemoryTripService(store: store, userRecordID: "_agus0001")
    }

    @Test func FirstOpenWithoutATripStopsLeftoverLocation() async {
        let counter = StopCounter()
        let viewModel = MakeViewModel(counter: counter)

        await viewModel.RefreshActiveTrip(tripService: MakePhone())

        #expect(counter.stops == 1)
    }

    @Test func OpeningHomeAgainDoesNotStopLocationAgain() async {
        let counter = StopCounter()
        let viewModel = MakeViewModel(counter: counter)

        await viewModel.RefreshActiveTrip(tripService: MakePhone())
        await viewModel.RefreshActiveTrip(tripService: MakePhone())

        #expect(counter.stops == 1)
    }

    @Test func FirstOpenWithATripLeavesLocationAlone() async throws {
        let store = InMemoryTripStore()
        _ = try await MakePhone(store: store).CreateTrip(plan: TripPlanFixtures.tunjunganToPakuwon, profile: nil)
        let counter = StopCounter()
        let viewModel = MakeViewModel(counter: counter)

        await viewModel.RefreshActiveTrip(tripService: MakePhone(store: store))

        #expect(counter.stops == 0)
    }

    @Test func UnreachableICloudLeavesLocationAloneUntilItAnswers() async {
        let counter = StopCounter()
        let viewModel = MakeViewModel(counter: counter)
        let offline = MakePhone()
        offline.simulatedFailure = .noNetwork

        await viewModel.RefreshActiveTrip(tripService: offline)
        #expect(counter.stops == 0)

        await viewModel.RefreshActiveTrip(tripService: MakePhone())
        #expect(counter.stops == 1)
    }
}

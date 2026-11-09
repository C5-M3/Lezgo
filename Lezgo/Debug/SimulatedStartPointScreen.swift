//
//  SimulatedStartPointScreen.swift
//  Lezgo
//
//  Created by Nathan Sudiara on 06/11/26.
//

#if DEBUG
import SwiftUI

/// The trip map just after Start Trip, with ten cars still parked together at the start point, on Budi's phone. It
/// shows how the cars' card looks for a big group. Debug builds only.
struct SimulatedStartPointScreen: View {
    @State private var tripService = InMemoryTripService(
        store: InMemoryTripStore(trips: [Self.State()]),
        userRecordID: "_sample-\(SampleTrip.budiID.uuidString)"
    )

    private static let names = ["Agus", "Budi", "Citra", "Dewi", "Eka", "Fajar", "Gita", "Hadi", "Indah", "Joko"]

    var body: some View {
        TripMapView(
            viewModel: TripMapViewModel(
                tripID: SampleTrip.tripID,
                myParticipantID: SampleTrip.budiID,
                tripService: tripService,
                navigator: SimulatedTripMapNavigator(),
                streetNameService: LiveStreetNameService()
            ),
            onReturnToTripRoom: { _ in }
        )
    }

    /// The sample trip just started, with the leader last in the list so the card has to bring it to the front.
    private static func State(now: Date = .now) -> TripState {
        var state = SampleTrip.State(status: .inTrip, now: now)
        state.trip.startedAt = now
        state.trip.currentWaypointIndex = 1
        let start = state.waypoints[0].coordinate
        let ids = [SampleTrip.budiID, SampleTrip.citraID] + (2..<names.count - 1).map { _ in UUID() }
            + [SampleTrip.agusID]
        let names = ["Budi", "Citra"] + Array(Self.names.dropFirst(3)) + ["Agus"]
        state.participants = zip(ids, names).enumerated().map { index, car in
            Participant(
                id: car.0,
                tripID: SampleTrip.tripID,
                userRecordID: "_sample-\(car.0.uuidString)",
                displayName: car.1,
                carDescription: "Car \(index + 1)",
                // Two rows of five parking spaces, 3 m apart.
                coordinate: Coordinate(
                    latitude: start.latitude + Double(index / 5) * 6 / 110_600,
                    longitude: start.longitude + Double(index % 5) * 3 / 110_600
                ),
                speedKmh: 0,
                motionState: .stopped,
                alert: .none,
                lastSeenAt: now
            )
        }
        return state
    }
}

#Preview {
    SimulatedStartPointScreen()
}
#endif

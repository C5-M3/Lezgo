//
//  SyncCheckMapView.swift
//  Lezgo
//
//  Created by Nathan Sudiara on 27/10/26.
//

#if DEBUG
import SwiftUI

/// The trip map opened from Sync Check: real trip data from `TripService`, this phone's real GPS shared every
/// second, and simulated turn guidance until the routing service lands (#72). For checking #170 on real phones.
struct SyncCheckMapView: View {
    let tripService: any TripService
    let tripID: UUID
    let myParticipantID: UUID
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            TripMapView(
                viewModel: TripMapViewModel(
                    tripID: tripID,
                    myParticipantID: myParticipantID,
                    tripService: tripService,
                    navigator: SimulatedTripMapNavigator(),
                    streetNameService: LiveStreetNameService(),
                    locationSharer: LocationSharer(
                        tripService: tripService,
                        locationProvider: LiveLocationProvider(),
                        tripID: tripID,
                        participantID: myParticipantID
                    ),
                    directionsService: LiveDirectionsService()
                )
            )
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: { Text(verbatim: "Close") }
                }
            }
        }
    }
}

#Preview {
    SyncCheckMapView(
        tripService: SampleTrip.Service(status: .inTrip, me: SampleTrip.budiID),
        tripID: SampleTrip.tripID,
        myParticipantID: SampleTrip.budiID
    )
}
#endif

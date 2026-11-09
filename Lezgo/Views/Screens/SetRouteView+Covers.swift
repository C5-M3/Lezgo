//
//  SetRouteView+Covers.swift
//  Lezgo
//
//  Created by Farrell Sudjatmiko on 05/11/26.
//

import SwiftUI

extension SetRouteView {
    @ViewBuilder
    func tripRoomCover(session: TripSession) -> some View {
        TripRoomView(
            viewModel: TripRoomViewModel(
                tripService: tripService,
                tripID: session.state.trip.id,
                myParticipantID: session.myParticipantID,
                initialState: session.state,
                activeTripStorage: viewModel.activeTripStorage,
                locationSharer: LocationSharer(
                    tripService: tripService,
                    tripID: session.state.trip.id,
                    participantID: session.myParticipantID
                )
            ),
            onTripStarted: {
                activeMapSession = session
            }
        )
        .fullScreenCover(
            item: $activeMapSession,
            onDismiss: {
                viewModel.activeTripStorage.ClearActiveTrip()
                activeMapSession = nil
                HandleTripRoomDismissed()
            },
            content: { mapSession in
                tripMapCover(mapSession: mapSession)
            }
        )
    }

    @ViewBuilder
    func tripMapCover(mapSession: TripSession) -> some View {
        TripMapView(
            viewModel: TripMapViewModel(
                session: mapSession,
                tripService: tripService,
                activeTripStorage: viewModel.activeTripStorage
            ),
            onClose: {
                viewModel.activeTripStorage.ClearActiveTrip()
                activeMapSession = nil
                HandleTripRoomDismissed()
            }
        )
    }
}

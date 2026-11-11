//
//  TripRoomHeader.swift
//  Lezgo
//
//  Created by Oky Faishal on 26/10/26.
//

import SwiftUI

/// The map preview with "Lez Get Ready!" on its lower edge, fading into the black page like the hi-fi. At the
/// accessibility text sizes the title wraps over several lines, so it moves under the map instead of covering it.
struct TripRoomHeader: View {
    let viewModel: TripRoomViewModel
    /// How far the page is pulled down past its top; the map is zoomed by that much, so no black gap opens above it.
    var pullDistance: CGFloat = 0
    /// Fixed, not scaled with Dynamic Type: at large text sizes the map would push the overview off the screen.
    private let mapHeight: CGFloat = 320
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 8) {
                map
                title
            }
        } else {
            map.overlay(alignment: .bottomLeading) { title }
        }
    }

    private var map: some View {
        TripRoomMapPreview(
            start: viewModel.startPoint,
            destination: viewModel.destination,
            polyline: viewModel.routePolyline,
            showsNames: !dynamicTypeSize.isAccessibilitySize
        )
        .frame(height: mapHeight)
        .overlay(alignment: .bottom) {
            LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom)
                .frame(height: mapHeight / 2)
                .allowsHitTesting(false)
        }
        // A zoom of the picture, not a resize: resizing the map makes MapKit reframe the route, and it would stay
        // zoomed in after the finger lets go. Anchored at the bottom, the map grows upward over the gap, then shrinks
        // back to its size as the page settles.
        .scaleEffect(1 + pullDistance / mapHeight, anchor: .bottom)
    }

    private var title: some View {
        Text("Lez Get Ready!")
            .font(.largeTitle.weight(.black))
            .foregroundStyle(.white)
            .padding(.horizontal)
            .accessibilityAddTraits(.isHeader)
    }
}

#if DEBUG
#Preview("Accessibility XXXL") {
    TripRoomHeader(viewModel: TripRoomViewModel(
        tripService: SampleTrip.Service(status: .lobby, me: SampleTrip.budiID),
        tripID: SampleTrip.tripID,
        myParticipantID: SampleTrip.budiID,
        initialState: SampleTrip.State(status: .lobby)
    ))
    .background(.black)
    .dynamicTypeSize(.accessibility5)
}
#endif

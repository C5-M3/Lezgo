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
        .visualEffect { content, proxy in
            let pull = proxy.frame(in: .scrollView).minY
            return content.scaleEffect(Self.PullZoom(pull: pull, mapHeight: mapHeight), anchor: .bottom)
        }
    }

    /// Pulling the page down moves the map down with it and would show black above it. Zooming the map around its
    /// bottom edge by the pulled distance keeps its top at the top of the screen and its bottom where the page has it.
    /// At rest, or when scrolled up, the map keeps its own size.
    static func PullZoom(pull: CGFloat, mapHeight: CGFloat) -> CGFloat {
        1 + max(0, pull) / mapHeight
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

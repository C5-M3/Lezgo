//
//  TripRoomHeader.swift
//  Lezgo
//
//  Created by Oky Faishal on 26/10/26.
//

import SwiftUI

/// The map preview with "Lez Get Ready !" on its lower edge, fading into the black page like the hi-fi.
struct TripRoomHeader: View {
    let viewModel: TripRoomViewModel
    /// Fixed, not scaled with Dynamic Type: at large text sizes the map would push the overview off the screen.
    private let mapHeight: CGFloat = 320

    var body: some View {
        TripRoomMapPreview(
            start: viewModel.startPoint,
            destination: viewModel.destination,
            polyline: viewModel.routePolyline
        )
        .frame(height: mapHeight)
        .overlay(alignment: .bottom) {
            LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom)
                .frame(height: mapHeight / 2)
                .allowsHitTesting(false)
        }
        .overlay(alignment: .bottomLeading) {
            Text("Lez Get Ready !")
                .font(.largeTitle.weight(.black))
                .foregroundStyle(Color(.brandYellow))
                .padding(.horizontal)
                .accessibilityAddTraits(.isHeader)
        }
    }
}

//
//  TripMapCameraControls.swift
//  Lezgo
//
//  Created by Nathan Sudiara on 26/10/26.
//

import SwiftUI

/// The round map buttons: show the whole route, and follow my car where the map has no location button of its own.
struct TripMapCameraControls: View {
    let cameraMode: TripMapViewModel.CameraMode
    let showWholeRoute: () -> Void
    /// Follows this phone's car; `nil` hides the button when the map's own location button does it.
    let followMyCar: (() -> Void)?

    var body: some View {
        VStack(spacing: 12) {
            Button(
                .tripMapShowWholeRoute,
                systemImage: "point.topleft.down.to.point.bottomright.curvepath",
                action: showWholeRoute
            )
                .accessibilityAddTraits(cameraMode == .wholeRoute ? .isSelected : [])
            if let followMyCar {
                Button(
                    .tripMapFollowMyCar,
                    systemImage: cameraMode == .followMyCar ? "location.fill" : "location",
                    action: followMyCar
                )
                .accessibilityAddTraits(cameraMode == .followMyCar ? .isSelected : [])
            }
        }
        .labelStyle(.iconOnly)
        .font(.title2)
        .buttonStyle(.glass)
        .buttonBorderShape(.circle)
        .controlSize(.large)
    }
}

#Preview("Following my car") {
    TripMapCameraControls(cameraMode: .followMyCar, showWholeRoute: {}, followMyCar: {})
        .padding()
}

#Preview("With the map's location button") {
    TripMapCameraControls(cameraMode: .followMyCar, showWholeRoute: {}, followMyCar: nil)
        .padding()
}

#Preview("Largest text") {
    TripMapCameraControls(cameraMode: .wholeRoute, showWholeRoute: {}, followMyCar: {})
        .padding()
        .dynamicTypeSize(.accessibility5)
}

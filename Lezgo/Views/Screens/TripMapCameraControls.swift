//
//  TripMapCameraControls.swift
//  Lezgo
//
//  Created by Nathan Sudiara on 26/10/26.
//

import SwiftUI

/// The round map buttons: Edit Route (leader only), show the whole route, and follow my car.
struct TripMapCameraControls: View {
    let cameraMode: TripMapViewModel.CameraMode
    let showWholeRoute: () -> Void
    /// Follows this phone's car; `nil` hides the button when the map's own location button does it.
    let followMyCar: (() -> Void)?
    /// Opens Edit Route; `nil` hides the button, as on a member's phone.
    var editRoute: (() -> Void)?

    var body: some View {
        VStack(spacing: 12) {
            if let editRoute {
                Button(.tripMapEditRoute, systemImage: "pencil", action: editRoute)
            }
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
    TripMapCameraControls(cameraMode: .followMyCar, showWholeRoute: {}, followMyCar: nil, editRoute: {})
        .padding()
}

#Preview("Leader, largest text") {
    TripMapCameraControls(cameraMode: .wholeRoute, showWholeRoute: {}, followMyCar: {}, editRoute: {})
        .padding()
        .dynamicTypeSize(.accessibility5)
}

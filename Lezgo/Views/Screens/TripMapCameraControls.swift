//
//  TripMapCameraControls.swift
//  Lezgo
//
//  Created by Nathan Sudiara on 26/10/26.
//

import SwiftUI

/// The round map buttons above the bottom card: show the whole route, and follow my car.
struct TripMapCameraControls: View {
    let cameraMode: TripMapViewModel.CameraMode
    let showWholeRoute: () -> Void
    let followMyCar: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Button(
                .tripMapShowWholeRoute,
                systemImage: "point.topleft.down.to.point.bottomright.curvepath",
                action: showWholeRoute
            )
            .accessibilityAddTraits(cameraMode == .wholeRoute ? .isSelected : [])

            Button(
                .tripMapFollowMyCar,
                systemImage: cameraMode == .followMyCar ? "location.fill" : "location",
                action: followMyCar
            )
            .accessibilityAddTraits(cameraMode == .followMyCar ? .isSelected : [])
        }
        .labelStyle(.iconOnly)
        .buttonStyle(RoundStyle())
    }
}

extension TripMapCameraControls {
    /// A dark circle of a fixed size. The icon is a map graphic, so it stops growing before it would leave the circle.
    struct RoundStyle: ButtonStyle {
        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .font(.title.weight(.semibold))
                .dynamicTypeSize(...DynamicTypeSize.xxLarge)
                .foregroundStyle(Color(.tripCardText))
                .frame(width: 61, height: 61)
                .background(Color(.tripCard), in: .circle)
                .contentShape(.circle)
                .opacity(configuration.isPressed ? 0.7 : 1)
        }
    }
}

#Preview("Following my car") {
    TripMapCameraControls(cameraMode: .followMyCar, showWholeRoute: {}, followMyCar: {})
        .padding()
}

#Preview("Largest text") {
    TripMapCameraControls(cameraMode: .wholeRoute, showWholeRoute: {}, followMyCar: {})
        .padding()
        .dynamicTypeSize(.accessibility5)
}

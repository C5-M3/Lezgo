//
//  TripMapCameraControls.swift
//  Lezgo
//
//  Created by Nathan Sudiara on 26/10/26.
//

import SwiftUI

/// The round map buttons above the bottom card: mute, show the whole route, and follow my car.
struct TripMapCameraControls: View {
    let cameraMode: TripMapViewModel.CameraMode
    let isMuted: Bool
    let toggleMute: () -> Void
    let showWholeRoute: () -> Void
    let followMyCar: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 14) {
            // Named after what a tap does, like the mute button in Apple Maps.
            Button(
                isMuted ? .tripMapUnmute : .tripMapMute,
                systemImage: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill",
                action: toggleMute
            )
            .contentTransition(.symbolEffect(.replace))

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
        // The arrow fills in as the camera starts following, instead of blinking.
        .contentTransition(.symbolEffect(.replace))
        .animation(Animation.lezgoSwap.Respecting(reduceMotion: reduceMotion), value: cameraMode)
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
                .pressFeedback(isPressed: configuration.isPressed)
        }
    }
}

#Preview("Following my car") {
    TripMapCameraControls(cameraMode: .followMyCar, isMuted: false, toggleMute: {}, showWholeRoute: {}, followMyCar: {})
        .padding()
}

#Preview("Muted") {
    TripMapCameraControls(cameraMode: .followMyCar, isMuted: true, toggleMute: {}, showWholeRoute: {}, followMyCar: {})
        .padding()
}

#Preview("Largest text") {
    TripMapCameraControls(cameraMode: .wholeRoute, isMuted: false, toggleMute: {}, showWholeRoute: {}, followMyCar: {})
        .padding()
        .dynamicTypeSize(.accessibility5)
}

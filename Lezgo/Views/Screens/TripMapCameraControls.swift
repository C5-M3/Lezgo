//
//  TripMapCameraControls.swift
//  Lezgo
//
//  Created by Nathan Sudiara on 26/10/26.
//

import SwiftUI

/// The round map buttons above the bottom card: the compass while the map is turned, mute, and one camera button
/// that follows my car or shows the whole route, as in Apple Maps on CarPlay.
struct TripMapCameraControls: View {
    let mapHeading: TripMapHeading
    let cameraMode: TripMapViewModel.CameraMode
    let isMuted: Bool
    let toggleMute: () -> Void
    let toggleCamera: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var isFollowingMyCar: Bool { cameraMode == .followMyCar }

    var body: some View {
        GlassEffectContainer(spacing: 14) {
        VStack(spacing: 14) {
            TripMapCompass(heading: mapHeading)

            // Named after what a tap does, like the mute button in Apple Maps.
            Button(
                isMuted ? .tripMapUnmute : .tripMapMute,
                systemImage: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill",
                action: toggleMute
            )

            // Also named after what a tap does: the whole route while the camera follows my car, and back to my
            // car from anywhere else (the whole route, a map moved by hand, another car).
            Button(
                isFollowingMyCar ? .tripMapShowWholeRoute : .tripMapFollowMyCar,
                systemImage: isFollowingMyCar
                    ? "point.topleft.down.to.point.bottomright.curvepath"
                    : "location.fill",
                action: toggleCamera
            )
        }
        .labelStyle(.iconOnly)
        .font(.title.weight(.semibold))
        .lezgoGlassButton(.round, side: Self.buttonSide)
        // The icons change into each other instead of blinking.
        .contentTransition(.symbolEffect(.replace))
        .animation(Animation.lezgoSwap.Respecting(reduceMotion: reduceMotion), value: cameraMode)
        }
    }

    /// The size of every round map button, as in the Hi-Fi.
    static let buttonSide: CGFloat = 61
}

#Preview("Following my car") {
    TripMapCameraControls(
        mapHeading: TripMapHeading(),
        cameraMode: .followMyCar,
        isMuted: false,
        toggleMute: {},
        toggleCamera: {}
    )
    .padding()
}

#Preview("Muted") {
    TripMapCameraControls(
        mapHeading: TripMapHeading(),
        cameraMode: .followMyCar,
        isMuted: true,
        toggleMute: {},
        toggleCamera: {}
    )
    .padding()
}

#Preview("Largest text") {
    TripMapCameraControls(
        mapHeading: TripMapHeading(),
        cameraMode: .wholeRoute,
        isMuted: false,
        toggleMute: {},
        toggleCamera: {}
    )
    .padding()
    .dynamicTypeSize(.accessibility5)
}

import SwiftUI

/// The two round map buttons: show the whole route, and follow my car.
struct TripMapCameraControls: View {
    let cameraMode: TripMapCameraMode
    let showWholeRoute: () -> Void
    let followMyCar: () -> Void

    var body: some View {
        VStack(spacing: 12) {
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

#Preview("Whole route, largest text") {
    TripMapCameraControls(cameraMode: .wholeRoute, showWholeRoute: {}, followMyCar: {})
        .padding()
        .dynamicTypeSize(.accessibility5)
}

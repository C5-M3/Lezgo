//
//  TripMapCamera.swift
//  Lezgo
//
//  Created by Nathan Sudiara on 06/11/26.
//

import Foundation

/// What the trip map camera follows, and where it goes back to when a tapped car's status card closes
/// (`specs/UserStories.md` → US-06, "Car status").
struct TripMapCamera {
    private(set) var mode: TripMapViewModel.CameraMode = .followMyCar
    /// Where the camera was before a tapped car took it, and where the tap put it.
    private var carFocus: (before: TripMapViewModel.CameraMode, focused: TripMapViewModel.CameraMode)?

    mutating func ShowWholeRoute() {
        mode = .wholeRoute
    }

    mutating func FollowMyCar() {
        mode = .followMyCar
    }

    /// The one camera button, as in Apple Maps on CarPlay: while the camera follows this phone's car it shows the
    /// whole route; from anywhere else (the whole route, a map moved by hand, another car) it follows the car again.
    mutating func Toggle() {
        mode = mode == .followMyCar ? .wholeRoute : .followMyCar
    }

    /// The person panned or zoomed the map by hand.
    mutating func StopFollowing() {
        mode = .free
    }

    /// A tapped car takes the camera (this phone's own car is simply followed). With `nil` the card closed: the
    /// camera goes back to where it was, unless the person moved it since.
    mutating func Focus(on carID: UUID?, myCarID: UUID) {
        guard let carID else {
            if let carFocus, carFocus.focused == mode { mode = carFocus.before }
            carFocus = nil
            return
        }
        let before = carFocus?.before ?? mode
        mode = carID == myCarID ? .followMyCar : .followCar(carID)
        carFocus = (before: before, focused: mode)
    }
}

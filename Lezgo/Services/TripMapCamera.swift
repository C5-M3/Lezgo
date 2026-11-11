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
    /// How long after a camera button tap the map is still flying to the button's choice, in seconds.
    static let buttonMoveTime: TimeInterval = 2
    /// How far from the car the 3D camera starts, in metres, and how far zoom in (`+`) and out (`-`) can take it.
    static let defaultFollowDistance = 600.0
    static let minFollowDistance = 200.0
    static let maxFollowDistance = 12_000.0
    static let zoomFactor = 1.5
    private static let referencePinWidth = 64.0
    private static let maxLongSideRatio = 0.078
    private static let maxShortSideRatio = 0.125
    private static let minZoomScale = 0.38

    private(set) var mode: TripMapViewModel.CameraMode = .followMyCar
    private(set) var followDistance = defaultFollowDistance

    /// Scales a car pin or group card so it takes a small, consistent share of the map on every screen size and
    /// shrinks as the camera zooms out instead of covering the route.
    static func MarkerScale(
        mapWidth: Double,
        mapHeight: Double,
        cameraDistance: Double = defaultFollowDistance,
        carCount: Int = 1
    ) -> Double {
        guard mapWidth > 0, mapHeight > 0 else { return 1 }
        let longSide = max(mapWidth, mapHeight)
        let shortSide = min(mapWidth, mapHeight)
        let targetWidth = min(longSide * maxLongSideRatio, shortSide * maxShortSideRatio)
        let screenScale = min(max(targetWidth / referencePinWidth, 0.30), 1.0)
        let zoomScale = cameraDistance > defaultFollowDistance
            ? max(pow(defaultFollowDistance / cameraDistance, 0.45), minZoomScale)
            : 1.0
        let groupScale = 1.0 / pow(Double(min(max(carCount, 1), 5)), 0.25)
        return screenScale * zoomScale * groupScale
    }
    /// Bumped on every `+` or `-` tap so the map zooms even when it is not following a car.
    private(set) var zoomStep = 0
    private(set) var lastZoomFactor = 1.0
    /// When a camera or zoom button was last tapped.
    private var buttonTappedAt: Date?
    /// Where the camera was before a tapped car took it, and where the tap put it.
    private var carFocus: (before: TripMapViewModel.CameraMode, focused: TripMapViewModel.CameraMode)?

    /// The one camera button, as in Apple Maps on CarPlay: while the camera follows this phone's car it shows the
    /// whole route; from anywhere else (the whole route, a map moved by hand, another car) it follows the car again.
    mutating func Toggle(at now: Date) {
        mode = mode == .followMyCar ? .wholeRoute : .followMyCar
        buttonTappedAt = now
    }

    mutating func ZoomIn(at now: Date) {
        followDistance = max(Self.minFollowDistance, followDistance / Self.zoomFactor)
        if mode == .wholeRoute { mode = .free }
        zoomStep += 1
        lastZoomFactor = 1 / Self.zoomFactor
        buttonTappedAt = now
    }

    mutating func ZoomOut(at now: Date) {
        followDistance = min(Self.maxFollowDistance, followDistance * Self.zoomFactor)
        if mode == .wholeRoute { mode = .free }
        zoomStep += 1
        lastZoomFactor = Self.zoomFactor
        buttonTappedAt = now
    }

    /// The map says the person panned or zoomed it by hand. Right after a camera button tap the map also says this
    /// when the next tap cuts its flight short, or when it stops following the phone's own location; then it is
    /// not the person, and the button's choice stays.
    mutating func StopFollowing(at now: Date) {
        if let buttonTappedAt, now.timeIntervalSince(buttonTappedAt) < Self.buttonMoveTime { return }
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

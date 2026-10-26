/// What the trip map camera follows.
enum TripMapCameraMode: Hashable {
    /// The camera stays on this phone's car as it moves.
    case followMyCar
    /// The camera shows the whole route; it no longer moves with the car.
    case wholeRoute
    /// The person moved the map by hand; the camera stays where they left it.
    case free
}

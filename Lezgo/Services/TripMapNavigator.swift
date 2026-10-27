import Foundation

/// Works out the next turn and the time left for this phone's car.
///
/// When the routing service (#72) lands, a live type wraps its MapKit directions. Until then the app uses
/// `SimulatedTripMapNavigator`, and tests use `MockTripMapNavigator`.
protocol TripMapNavigator {
    func Guidance(from position: Coordinate, along state: TripState) async throws -> TripMapGuidance
}

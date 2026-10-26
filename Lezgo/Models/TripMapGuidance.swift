import Foundation

/// Turn-by-turn guidance for this phone's car: the next turn and the time left to the destination.
struct TripMapGuidance: Hashable {
    var direction: TripMapTurnDirection
    /// The instruction from the routing service, for example "Turn right". MapKit already localizes it.
    var instruction: String
    var distanceToTurn: Measurement<UnitLength>
    var timeLeft: Duration
}

import Foundation
@testable import Lezgo

/// Plans and phones for testing `TripService` implementations.
enum TripPlanFixtures {
    static let tunjunganToPakuwon = TripPlan(
        waypoints: [
            PlannedWaypoint(kind: .start, name: "Tunjungan Plaza", coordinate: TripFixtures.tunjunganPlaza),
            PlannedWaypoint(kind: .checkpoint, name: "Ciputra World", coordinate: TripFixtures.ciputraWorld),
            PlannedWaypoint(kind: .destination, name: "Pakuwon mall", coordinate: TripFixtures.pakuwonMall)
        ],
        polyline: [TripFixtures.tunjunganPlaza, TripFixtures.ciputraWorld, TripFixtures.pakuwonMall]
    )

    static let ciputraToPakuwonCity = TripPlan(
        waypoints: [
            PlannedWaypoint(kind: .start, name: "Ciputra World", coordinate: TripFixtures.ciputraWorld),
            PlannedWaypoint(kind: .destination, name: "Pakuwon city mall", coordinate: TripFixtures.pakuwonMall)
        ],
        polyline: [TripFixtures.ciputraWorld, TripFixtures.pakuwonMall]
    )

    static let agusProfile = ParticipantProfile(displayName: "Agus", carDescription: "Black Avanza")
    static let budiProfile = ParticipantProfile(displayName: "Budi", carDescription: "White Brio")
    static let citraProfile = ParticipantProfile(displayName: "Citra", carDescription: "Red Jazz")
}

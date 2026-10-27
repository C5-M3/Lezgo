import Foundation

/// Who has arrived at the destination (`specs/UserStories.md` → US-07, "Arrive").
///
/// A car has arrived within 20 m of the destination. Offline members count as not arrived, members without a
/// position yet count as not arrived, and members who left are no longer in the trip, so they are not counted.
struct TripMapArrival: Hashable {
    /// The arrival radius around the destination, in metres.
    static let radius: Double = 20

    var hasArrived: Bool
    var everyoneHasArrived: Bool

    static func Check(_ snapshot: TripMapSnapshot, at date: Date) -> TripMapArrival {
        guard let destination = snapshot.waypoints.first(where: { $0.kind == .destination }) else {
            return TripMapArrival(hasArrived: false, everyoneHasArrived: false)
        }
        let cars = Dictionary(snapshot.cars.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let isThere = { (car: TripMapCar) in car.coordinate.Distance(to: destination.coordinate) <= radius }
        let hasArrived = cars[snapshot.myParticipantID].map(isThere) ?? false
        let everyoneHasArrived = snapshot.memberIDs.isEmpty == false && snapshot.memberIDs.allSatisfy { memberID in
            guard let car = cars[memberID] else { return false }
            return car.IsOnline(at: date) && isThere(car)
        }
        return TripMapArrival(hasArrived: hasArrived, everyoneHasArrived: everyoneHasArrived)
    }
}

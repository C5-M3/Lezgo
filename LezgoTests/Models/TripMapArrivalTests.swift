import Foundation
import Testing
@testable import Lezgo

struct TripMapArrivalTests {
    private typealias Fixtures = TripMapFixtures

    private func Check(_ cars: [TripMapCar], memberIDs: [UUID]? = nil) -> TripMapArrival {
        TripMapArrival.Check(Fixtures.Snapshot(me: Fixtures.budiID, cars: cars, memberIDs: memberIDs), at: Fixtures.now)
    }

    @Test(arguments: [(metres: 0.0, arrived: true), (19, true), (21, false), (500, false)])
    func MyCarArrivesWithinTwentyMetres(metres: Double, arrived: Bool) {
        let budi = Fixtures.CarNearDestination(id: Fixtures.budiID, name: "Budi", metres: metres)

        #expect(Check([budi]).hasArrived == arrived)
    }

    @Test func EveryoneArrivedWhenAllCarsAreThere() {
        let cars = [
            Fixtures.CarNearDestination(id: Fixtures.agusID, name: "Agus", metres: 5),
            Fixtures.CarNearDestination(id: Fixtures.budiID, name: "Budi", metres: 10),
            Fixtures.CarNearDestination(id: Fixtures.citraID, name: "Citra", metres: 15)
        ]

        let arrival = Check(cars)

        #expect(arrival.hasArrived)
        #expect(arrival.everyoneHasArrived)
    }

    @Test func OneLateCarMeansNotEveryone() {
        let cars = [
            Fixtures.CarNearDestination(id: Fixtures.agusID, name: "Agus", metres: 5),
            Fixtures.CarNearDestination(id: Fixtures.budiID, name: "Budi", metres: 10),
            Fixtures.CarNearDestination(id: Fixtures.citraID, name: "Citra", metres: 500)
        ]

        let arrival = Check(cars)

        #expect(arrival.hasArrived)
        #expect(arrival.everyoneHasArrived == false)
    }

    @Test func OfflineCarCountsAsNotArrived() {
        let cars = [
            Fixtures.CarNearDestination(id: Fixtures.budiID, name: "Budi", metres: 10),
            Fixtures.CarNearDestination(id: Fixtures.citraID, name: "Citra", metres: 5, lastSeenSecondsAgo: 180)
        ]

        #expect(Check(cars).everyoneHasArrived == false)
    }

    @Test func MemberWithoutAPositionCountsAsNotArrived() {
        let budi = Fixtures.CarNearDestination(id: Fixtures.budiID, name: "Budi", metres: 10)

        let arrival = Check([budi], memberIDs: [Fixtures.budiID, Fixtures.citraID])

        #expect(arrival.everyoneHasArrived == false)
    }

    @Test func MemberWhoLeftIsNotCounted() {
        let budi = Fixtures.CarNearDestination(id: Fixtures.budiID, name: "Budi", metres: 10)

        // Citra exited: she is no longer a member, so only Budi counts.
        #expect(Check([budi], memberIDs: [Fixtures.budiID]).everyoneHasArrived)
    }

    @Test func NoDestinationMeansNobodyArrived() {
        let budi = Fixtures.CarNearDestination(id: Fixtures.budiID, name: "Budi", metres: 0)
        let snapshot = Fixtures.Snapshot(cars: [budi], waypoints: [Fixtures.startPoint, Fixtures.checkpoint])

        let arrival = TripMapArrival.Check(snapshot, at: Fixtures.now)

        #expect(arrival.hasArrived == false)
        #expect(arrival.everyoneHasArrived == false)
    }
}

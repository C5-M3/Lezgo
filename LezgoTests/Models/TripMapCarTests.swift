import Foundation
import Testing
@testable import Lezgo

struct TripMapCarTests {
    @Test(arguments: [
        (secondsAgo: 0.0, isOnline: true),
        (secondsAgo: 119.0, isOnline: true),
        (secondsAgo: 120.0, isOnline: true),
        (secondsAgo: 121.0, isOnline: false),
        (secondsAgo: 180.0, isOnline: false)
    ])
    func CarIsOfflineOnlyAfterTwoMinutes(secondsAgo: Double, isOnline: Bool) {
        let car = TripMapFixtures.Car(id: UUID(), name: "Budi", lastSeenSecondsAgo: secondsAgo)

        #expect(car.IsOnline(at: TripMapFixtures.now) == isOnline)
    }

    @Test func CarWithLastSeenInTheFutureIsOnline() {
        // Phone clocks drift, so another phone's timestamp can be slightly ahead of ours.
        let car = TripMapFixtures.Car(id: UUID(), name: "Budi", lastSeenSecondsAgo: -5)

        #expect(car.IsOnline(at: TripMapFixtures.now))
    }
}

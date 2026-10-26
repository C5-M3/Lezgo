import Testing
@testable import Lezgo

struct TripMapWaypointTests {
    @Test(arguments: [
        (currentWaypointIndex: 0, isVisited: false),
        (currentWaypointIndex: 1, isVisited: false),
        (currentWaypointIndex: 2, isVisited: true),
        (currentWaypointIndex: 3, isVisited: true)
    ])
    func CheckpointIsVisitedOnceTheTripMovesPastIt(currentWaypointIndex: Int, isVisited: Bool) {
        let checkpoint = TripMapFixtures.checkpoint

        #expect(checkpoint.IsVisited(currentWaypointIndex: currentWaypointIndex) == isVisited)
    }
}

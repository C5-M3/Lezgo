import Foundation
import Testing
@testable import Lezgo

struct TripMapViewModelTests {
    private func MakeViewModel(
        snapshots: [TripMapSnapshot],
        service: MockTripMapService? = nil,
        navigator: MockTripMapNavigator = MockTripMapNavigator(results: [.success(TripMapFixtures.Guidance())])
    ) -> TripMapViewModel {
        TripMapViewModel(
            tripID: TripMapFixtures.tripID,
            service: service ?? MockTripMapService(snapshots: snapshots),
            navigator: navigator,
            clock: { TripMapFixtures.now }
        )
    }

    // MARK: Before the first update

    @Test func MapIsEmptyBeforeTheFirstUpdate() {
        let viewModel = MakeViewModel(snapshots: [])

        #expect(viewModel.carPins.isEmpty)
        #expect(viewModel.waypoints.isEmpty)
        #expect(viewModel.route.isEmpty)
        #expect(viewModel.destinationName == nil)
        #expect(viewModel.guidance == nil)
        #expect(viewModel.isLoading)
    }

    @Test func LoadingEndsWithTheFirstUpdate() async {
        let viewModel = MakeViewModel(snapshots: [TripMapFixtures.Snapshot()])

        await viewModel.Start()

        #expect(viewModel.isLoading == false)
    }

    @Test func StartListensToTheRightTrip() async {
        let service = MockTripMapService(snapshots: [])
        let viewModel = MakeViewModel(snapshots: [], service: service)

        await viewModel.Start()

        #expect(service.requestedTripIDs == [TripMapFixtures.tripID])
    }

    // MARK: Cars

    @Test func MapShowsEveryCar() async {
        let viewModel = MakeViewModel(snapshots: [TripMapFixtures.Snapshot()])

        await viewModel.Start()

        #expect(viewModel.carPins.map(\.displayName) == ["Agus", "Budi", "Citra"])
    }

    @Test func PinsMarkTheLeaderAndMyCar() async throws {
        let viewModel = MakeViewModel(snapshots: [TripMapFixtures.Snapshot(me: TripMapFixtures.budiID)])

        await viewModel.Start()

        let agus = try #require(viewModel.carPins.first { $0.id == TripMapFixtures.agusID })
        let budi = try #require(viewModel.carPins.first { $0.id == TripMapFixtures.budiID })
        #expect(agus.isLeader)
        #expect(agus.isMe == false)
        #expect(budi.isLeader == false)
        #expect(budi.isMe)
    }

    @Test func OfflineCarIsFadedAtItsLastPosition() async throws {
        let citra = TripMapFixtures.Car(id: TripMapFixtures.citraID, name: "Citra", lastSeenSecondsAgo: 180)
        let budi = TripMapFixtures.Car(id: TripMapFixtures.budiID, name: "Budi")
        let viewModel = MakeViewModel(snapshots: [TripMapFixtures.Snapshot(cars: [budi, citra])])

        await viewModel.Start()

        let citraPin = try #require(viewModel.carPins.first { $0.id == TripMapFixtures.citraID })
        let budiPin = try #require(viewModel.carPins.first { $0.id == TripMapFixtures.budiID })
        #expect(citraPin.isOffline)
        #expect(citraPin.coordinate == citra.coordinate)
        #expect(budiPin.isOffline == false)
    }

    @Test func StoppedCarKeepsItsMotionState() async throws {
        let budi = TripMapFixtures.Car(id: TripMapFixtures.budiID, name: "Budi", motionState: .stopped)
        let viewModel = MakeViewModel(snapshots: [TripMapFixtures.Snapshot(cars: [budi])])

        await viewModel.Start()

        #expect(viewModel.carPins.first?.motionState == .stopped)
    }

    @Test func LatestUpdateReplacesTheCars() async {
        let first = TripMapFixtures.Snapshot()
        let budiOnly = TripMapFixtures.Snapshot(cars: [TripMapFixtures.Car(id: TripMapFixtures.budiID, name: "Budi")])
        let viewModel = MakeViewModel(snapshots: [first, budiOnly])

        await viewModel.Start()

        #expect(viewModel.carPins.map(\.displayName) == ["Budi"])
    }

    @Test func VeryLongNameIsKeptWhole() async {
        let longName = String(repeating: "Budi Santoso ", count: 20)
        let viewModel = MakeViewModel(snapshots: [
            TripMapFixtures.Snapshot(cars: [TripMapFixtures.Car(id: TripMapFixtures.budiID, name: longName)])
        ])

        await viewModel.Start()

        #expect(viewModel.carPins.first?.displayName == longName)
    }

    // MARK: Role

    @Test func LeaderPhoneKnowsItIsTheLeader() async {
        let viewModel = MakeViewModel(snapshots: [TripMapFixtures.Snapshot(me: TripMapFixtures.agusID)])

        await viewModel.Start()

        #expect(viewModel.isLeader)
    }

    @Test func MemberPhoneKnowsItIsNotTheLeader() async {
        let viewModel = MakeViewModel(snapshots: [TripMapFixtures.Snapshot(me: TripMapFixtures.budiID)])

        await viewModel.Start()

        #expect(viewModel.isLeader == false)
    }

    // MARK: Route and destination

    @Test func DestinationLabelUsesTheDestinationName() async {
        let viewModel = MakeViewModel(snapshots: [TripMapFixtures.Snapshot()])

        await viewModel.Start()

        #expect(viewModel.destinationName == "Pakuwon mall")
    }

    @Test func DestinationLabelIsEmptyWithoutADestination() async {
        let viewModel = MakeViewModel(snapshots: [
            TripMapFixtures.Snapshot(waypoints: [TripMapFixtures.startPoint, TripMapFixtures.checkpoint])
        ])

        await viewModel.Start()

        #expect(viewModel.destinationName == nil)
    }

    @Test func WaypointsAreInRouteOrder() async {
        let viewModel = MakeViewModel(snapshots: [TripMapFixtures.Snapshot()])

        await viewModel.Start()

        #expect(viewModel.waypoints.map(\.name) == ["Tunjungan Plaza", "Ciputra World", "Pakuwon mall"])
    }

    @Test func CheckpointIsVisitedAfterTheLeaderPassesIt() async {
        let viewModel = MakeViewModel(snapshots: [TripMapFixtures.Snapshot(currentWaypointIndex: 2)])

        await viewModel.Start()

        #expect(viewModel.IsVisited(TripMapFixtures.startPoint))
        #expect(viewModel.IsVisited(TripMapFixtures.checkpoint))
        #expect(viewModel.IsVisited(TripMapFixtures.destination) == false)
    }

    @Test func NothingIsVisitedBeforeTheFirstUpdate() {
        let viewModel = MakeViewModel(snapshots: [])

        #expect(viewModel.IsVisited(TripMapFixtures.startPoint) == false)
    }

    @Test func RouteLineFollowsTheSnapshot() async {
        let snapshot = TripMapFixtures.Snapshot()
        let viewModel = MakeViewModel(snapshots: [snapshot])

        await viewModel.Start()

        #expect(viewModel.route == snapshot.route)
    }

    // MARK: Guidance

    @Test func GuidanceStartsFromMyCar() async throws {
        let snapshot = TripMapFixtures.Snapshot(me: TripMapFixtures.budiID)
        let navigator = MockTripMapNavigator(results: [.success(TripMapFixtures.Guidance())])
        let viewModel = MakeViewModel(snapshots: [snapshot], navigator: navigator)

        await viewModel.Start()

        let budi = try #require(snapshot.cars.first { $0.id == TripMapFixtures.budiID })
        #expect(navigator.requestedPositions == [budi.coordinate])
        #expect(viewModel.myCoordinate == budi.coordinate)
        #expect(viewModel.guidance?.timeLeft == .seconds(50 * 60))
    }

    @Test func GuidanceKeepsTheLastAnswerWhenRoutingFails() async {
        let snapshots = [TripMapFixtures.Snapshot(), TripMapFixtures.Snapshot()]
        let navigator = MockTripMapNavigator(results: [
            .success(TripMapFixtures.Guidance(minutesLeft: 50)),
            .failure(.init())
        ])
        let viewModel = MakeViewModel(snapshots: snapshots, navigator: navigator)

        await viewModel.Start()

        #expect(viewModel.guidance?.timeLeft == .seconds(50 * 60))
    }

    @Test func NoGuidanceWhenMyCarIsMissing() async {
        let strangerID = UUID()
        let navigator = MockTripMapNavigator(results: [.success(TripMapFixtures.Guidance())])
        let viewModel = MakeViewModel(snapshots: [TripMapFixtures.Snapshot(me: strangerID)], navigator: navigator)

        await viewModel.Start()

        #expect(navigator.requestedPositions.isEmpty)
        #expect(viewModel.guidance == nil)
        #expect(viewModel.myCoordinate == nil)
    }

    // MARK: Camera

    @Test func CameraFollowsMyCarByDefault() {
        let viewModel = MakeViewModel(snapshots: [])

        #expect(viewModel.cameraMode == .followMyCar)
    }

    @Test func ShowWholeRouteThenFollowMyCarAgain() {
        let viewModel = MakeViewModel(snapshots: [])

        viewModel.ShowWholeRoute()
        #expect(viewModel.cameraMode == .wholeRoute)

        viewModel.FollowMyCar()
        #expect(viewModel.cameraMode == .followMyCar)
    }

    @Test func RepeatedTapsKeepTheSameCameraMode() {
        let viewModel = MakeViewModel(snapshots: [])

        viewModel.ShowWholeRoute()
        viewModel.ShowWholeRoute()

        #expect(viewModel.cameraMode == .wholeRoute)
    }

    @Test func MovingTheMapByHandStopsFollowing() {
        let viewModel = MakeViewModel(snapshots: [])

        viewModel.StopFollowing()

        #expect(viewModel.cameraMode == .free)
    }

    @Test func FollowMyCarAfterMovingTheMapByHand() {
        let viewModel = MakeViewModel(snapshots: [])

        viewModel.StopFollowing()
        viewModel.FollowMyCar()

        #expect(viewModel.cameraMode == .followMyCar)
    }

    // MARK: Sharing my location

    @Test func OpenMapSharesMyLocation() async throws {
        let service = SampleTrip.Service(status: .inTrip, me: SampleTrip.budiID)
        let gps = MockLocationProvider()
        let sharer = LocationSharer(
            tripService: service,
            locationProvider: gps,
            tripID: SampleTrip.tripID,
            participantID: SampleTrip.budiID,
            interval: .milliseconds(10)
        )
        let viewModel = TripMapViewModel(
            tripID: SampleTrip.tripID,
            service: TripServiceMapAdapter(tripService: service, myParticipantID: SampleTrip.budiID),
            navigator: MockTripMapNavigator(results: [.success(TripMapFixtures.Guidance())]),
            locationSharer: sharer
        )

        let open = Task { await viewModel.Start() }
        try await Task.sleep(for: .milliseconds(10))
        gps.Send(LocationReading(coordinate: TripFixtures.pakuwonMall, speedKmh: 30, recordedAt: .now))
        try await Task.sleep(for: .milliseconds(60))
        open.cancel()
        await open.value

        #expect(sharer.sentCount > 0)
        let participants = try await service.FetchTrip(tripID: SampleTrip.tripID).participants
        let budi = participants.first { $0.id == SampleTrip.budiID }
        #expect(budi?.coordinate == TripFixtures.pakuwonMall)
    }

    @Test func LeavingTheMapStopsSharing() async throws {
        let service = SampleTrip.Service(status: .inTrip, me: SampleTrip.budiID)
        let gps = MockLocationProvider()
        let sharer = LocationSharer(
            tripService: service,
            locationProvider: gps,
            tripID: SampleTrip.tripID,
            participantID: SampleTrip.budiID,
            interval: .milliseconds(10)
        )
        let viewModel = TripMapViewModel(
            tripID: SampleTrip.tripID,
            service: TripServiceMapAdapter(tripService: service, myParticipantID: SampleTrip.budiID),
            navigator: MockTripMapNavigator(results: [.success(TripMapFixtures.Guidance())]),
            locationSharer: sharer
        )
        let open = Task { await viewModel.Start() }
        try await Task.sleep(for: .milliseconds(10))
        gps.Send(LocationReading(coordinate: TripFixtures.pakuwonMall, speedKmh: 30, recordedAt: .now))
        try await Task.sleep(for: .milliseconds(40))

        open.cancel()
        await open.value
        let sentWhenClosed = sharer.sentCount
        try await Task.sleep(for: .milliseconds(40))

        #expect(sharer.sentCount == sentWhenClosed)
    }
}

import Foundation
import Testing
@testable import Lezgo

struct TripMapViewModelTests {
    private typealias Fixtures = TripMapFixtures

    private func MakeViewModel(
        me: UUID = Fixtures.budiID,
        states: [TripState],
        service: MockTripService? = nil,
        navigator: MockTripMapNavigator = MockTripMapNavigator(results: [.success(Fixtures.Guidance())])
    ) -> TripMapViewModel {
        TripMapViewModel(
            tripID: Fixtures.tripID,
            myParticipantID: me,
            tripService: service ?? MockTripService(states: states),
            navigator: navigator,
            clock: { Fixtures.now }
        )
    }

    // MARK: Before the first update

    @Test func MapIsEmptyBeforeTheFirstUpdate() {
        let viewModel = MakeViewModel(states: [])

        #expect(viewModel.carPins.isEmpty)
        #expect(viewModel.waypoints.isEmpty)
        #expect(viewModel.route.isEmpty)
        #expect(viewModel.destinationName == nil)
        #expect(viewModel.guidance == nil)
        #expect(viewModel.isLoading)
    }

    @Test func LoadingEndsWithTheFirstUpdate() async {
        let viewModel = MakeViewModel(states: [Fixtures.State()])

        await viewModel.Start()

        #expect(viewModel.isLoading == false)
    }

    @Test func StartListensToTheRightTrip() async {
        let service = MockTripService(states: [])
        let viewModel = MakeViewModel(states: [], service: service)

        await viewModel.Start()

        #expect(service.requestedTripIDs == [Fixtures.tripID])
    }

    // MARK: Cars

    @Test func MapShowsEveryCar() async {
        let viewModel = MakeViewModel(states: [Fixtures.State()])

        await viewModel.Start()

        #expect(viewModel.carPins.map(\.displayName) == ["Agus", "Budi", "Citra"])
    }

    @Test func PinsMarkTheLeaderAndMyCar() async throws {
        let viewModel = MakeViewModel(me: Fixtures.budiID, states: [Fixtures.State()])

        await viewModel.Start()

        let agus = try #require(viewModel.carPins.first { $0.id == Fixtures.agusID })
        let budi = try #require(viewModel.carPins.first { $0.id == Fixtures.budiID })
        #expect(agus.isLeader)
        #expect(agus.isMe == false)
        #expect(budi.isLeader == false)
        #expect(budi.isMe)
    }

    @Test func MemberWithoutAPositionHasNoPinYet() async {
        var citra = Fixtures.Car(id: Fixtures.citraID, name: "Citra")
        citra.coordinate = nil
        let budi = Fixtures.Car(id: Fixtures.budiID, name: "Budi")
        let viewModel = MakeViewModel(states: [Fixtures.State(cars: [budi, citra])])

        await viewModel.Start()

        #expect(viewModel.carPins.map(\.displayName) == ["Budi"])
    }

    @Test func OfflineCarIsFadedAtItsLastPosition() async throws {
        let citra = Fixtures.Car(id: Fixtures.citraID, name: "Citra", lastSeenSecondsAgo: 180)
        let budi = Fixtures.Car(id: Fixtures.budiID, name: "Budi")
        let viewModel = MakeViewModel(states: [Fixtures.State(cars: [budi, citra])])

        await viewModel.Start()

        let citraPin = try #require(viewModel.carPins.first { $0.id == Fixtures.citraID })
        let budiPin = try #require(viewModel.carPins.first { $0.id == Fixtures.budiID })
        #expect(citraPin.isOffline)
        #expect(citraPin.coordinate == citra.coordinate)
        #expect(budiPin.isOffline == false)
    }

    @Test func StoppedCarKeepsItsMotionState() async throws {
        let budi = Fixtures.Car(id: Fixtures.budiID, name: "Budi", motionState: .stopped)
        let viewModel = MakeViewModel(states: [Fixtures.State(cars: [budi])])

        await viewModel.Start()

        #expect(viewModel.carPins.first?.motionState == .stopped)
    }

    @Test func LatestUpdateReplacesTheCars() async {
        let budiOnly = Fixtures.State(cars: [Fixtures.Car(id: Fixtures.budiID, name: "Budi")])
        let viewModel = MakeViewModel(states: [Fixtures.State(), budiOnly])

        await viewModel.Start()

        #expect(viewModel.carPins.map(\.displayName) == ["Budi"])
    }

    @Test func VeryLongNameIsKeptWhole() async {
        let longName = String(repeating: "Budi Santoso ", count: 20)
        let viewModel = MakeViewModel(states: [
            Fixtures.State(cars: [Fixtures.Car(id: Fixtures.budiID, name: longName)])
        ])

        await viewModel.Start()

        #expect(viewModel.carPins.first?.displayName == longName)
    }

    // MARK: Role

    @Test func LeaderPhoneKnowsItIsTheLeader() async {
        let viewModel = MakeViewModel(me: Fixtures.agusID, states: [Fixtures.State()])

        await viewModel.Start()

        #expect(viewModel.isLeader)
    }

    @Test func MemberPhoneKnowsItIsNotTheLeader() async {
        let viewModel = MakeViewModel(me: Fixtures.budiID, states: [Fixtures.State()])

        await viewModel.Start()

        #expect(viewModel.isLeader == false)
    }

    // MARK: Route and destination

    @Test func DestinationLabelUsesTheDestinationName() async {
        let viewModel = MakeViewModel(states: [Fixtures.State()])

        await viewModel.Start()

        #expect(viewModel.destinationName == "Pakuwon mall")
    }

    @Test func DestinationLabelIsEmptyWithoutADestination() async {
        let viewModel = MakeViewModel(states: [
            Fixtures.State(waypoints: [Fixtures.startPoint, Fixtures.checkpoint])
        ])

        await viewModel.Start()

        #expect(viewModel.destinationName == nil)
    }

    @Test func WaypointsAreInRouteOrder() async {
        let viewModel = MakeViewModel(states: [Fixtures.State()])

        await viewModel.Start()

        #expect(viewModel.waypoints.map(\.name) == ["Tunjungan Plaza", "Ciputra World", "Pakuwon mall"])
    }

    @Test func CheckpointIsVisitedAfterTheLeaderPassesIt() async {
        let viewModel = MakeViewModel(states: [Fixtures.State(currentWaypointIndex: 2)])

        await viewModel.Start()

        #expect(viewModel.IsVisited(Fixtures.startPoint))
        #expect(viewModel.IsVisited(Fixtures.checkpoint))
        #expect(viewModel.IsVisited(Fixtures.destination) == false)
    }

    @Test func NothingIsVisitedBeforeTheFirstUpdate() {
        let viewModel = MakeViewModel(states: [])

        #expect(viewModel.IsVisited(Fixtures.startPoint) == false)
    }

    @Test func RouteLineFollowsTheRoute() async {
        let state = Fixtures.State()
        let viewModel = MakeViewModel(states: [state])

        await viewModel.Start()

        #expect(viewModel.route == state.route?.polyline)
    }

    @Test func RouteLineFallsBackToTheWaypointsWithoutARoute() async {
        var state = Fixtures.State()
        state.route = nil
        let viewModel = MakeViewModel(states: [state])

        await viewModel.Start()

        #expect(viewModel.route == viewModel.waypoints.map(\.coordinate))
    }

    // MARK: Guidance

    @Test func GuidanceStartsFromMyCar() async throws {
        let state = Fixtures.State()
        let navigator = MockTripMapNavigator(results: [.success(Fixtures.Guidance())])
        let viewModel = MakeViewModel(me: Fixtures.budiID, states: [state], navigator: navigator)

        await viewModel.Start()

        let budi = try #require(state.participants.first { $0.id == Fixtures.budiID }?.coordinate)
        #expect(navigator.requestedPositions == [budi])
        #expect(viewModel.myCoordinate == budi)
        #expect(viewModel.guidance?.timeLeft == .seconds(50 * 60))
    }

    @Test func GuidanceKeepsTheLastAnswerWhenRoutingFails() async {
        let navigator = MockTripMapNavigator(results: [
            .success(Fixtures.Guidance(minutesLeft: 50)),
            .failure(.init())
        ])
        let viewModel = MakeViewModel(states: [Fixtures.State(), Fixtures.State()], navigator: navigator)

        await viewModel.Start()

        #expect(viewModel.guidance?.timeLeft == .seconds(50 * 60))
    }

    @Test func NoGuidanceWhenMyCarIsMissing() async {
        let navigator = MockTripMapNavigator(results: [.success(Fixtures.Guidance())])
        let viewModel = MakeViewModel(me: UUID(), states: [Fixtures.State()], navigator: navigator)

        await viewModel.Start()

        #expect(navigator.requestedPositions.isEmpty)
        #expect(viewModel.guidance == nil)
        #expect(viewModel.myCoordinate == nil)
    }

    // MARK: Camera

    @Test func CameraFollowsMyCarByDefault() {
        let viewModel = MakeViewModel(states: [])

        #expect(viewModel.cameraMode == .followMyCar)
    }

    @Test func ShowWholeRouteThenFollowMyCarAgain() {
        let viewModel = MakeViewModel(states: [])

        viewModel.ShowWholeRoute()
        #expect(viewModel.cameraMode == .wholeRoute)

        viewModel.FollowMyCar()
        #expect(viewModel.cameraMode == .followMyCar)
    }

    @Test func RepeatedTapsKeepTheSameCameraMode() {
        let viewModel = MakeViewModel(states: [])

        viewModel.ShowWholeRoute()
        viewModel.ShowWholeRoute()

        #expect(viewModel.cameraMode == .wholeRoute)
    }

    @Test func MovingTheMapByHandStopsFollowing() {
        let viewModel = MakeViewModel(states: [])

        viewModel.StopFollowing()

        #expect(viewModel.cameraMode == .free)
    }

    @Test func FollowMyCarAfterMovingTheMapByHand() {
        let viewModel = MakeViewModel(states: [])

        viewModel.StopFollowing()
        viewModel.FollowMyCar()

        #expect(viewModel.cameraMode == .followMyCar)
    }
}

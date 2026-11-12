//
//  TripAnswersTests.swift
//  LezgoTests
//
//  Created by Nathan Sudiara on 12/11/26.
//

import Foundation
import Testing
@testable import Lezgo

/// What Siri says about the trip (`specs/UserStories.md` → US-08).
struct TripAnswersTests {
    private typealias Fixtures = TripMapFixtures

    /// A point on the first leg of the route (start point → checkpoint, about 3.95 km), `fraction` of the way along.
    private static func OnRoute(_ fraction: Double) -> Coordinate {
        let start = Fixtures.startPoint.coordinate
        let checkpoint = Fixtures.checkpoint.coordinate
        return Coordinate(
            latitude: start.latitude + (checkpoint.latitude - start.latitude) * fraction,
            longitude: start.longitude + (checkpoint.longitude - start.longitude) * fraction
        )
    }

    /// A point `metres` north of the start point, off the route, which leaves the start point heading south.
    private static func NorthOfStart(_ metres: Double) -> Coordinate {
        let start = Fixtures.startPoint.coordinate
        return Coordinate(latitude: start.latitude + metres / 110_600, longitude: start.longitude)
    }

    private static func Car(_ id: UUID, _ name: String, at coordinate: Coordinate?) -> Participant {
        var car = Fixtures.Car(id: id, name: name)
        car.coordinate = coordinate
        return car
    }

    /// Budi's phone, with Agus (leader), Budi and Citra on the route.
    private static func Answers(
        agus: Coordinate? = OnRoute(0.5),
        budi: Coordinate? = OnRoute(0.2),
        citra: Coordinate? = OnRoute(0.1),
        me: UUID = Fixtures.budiID,
        streets: [UUID: String] = [:],
        guidance: TripMapGuidance? = nil,
        edit: (inout TripState) -> Void = { _ in }
    ) -> TripAnswers {
        var state = Fixtures.State(cars: [
            Car(Fixtures.agusID, "Agus", at: agus),
            Car(Fixtures.budiID, "Budi", at: budi),
            Car(Fixtures.citraID, "Citra", at: citra)
        ])
        edit(&state)
        let myCoordinate = state.participants.first { $0.id == me }?.coordinate
        return TripAnswers(
            state: state,
            myParticipantID: me,
            myCoordinate: myCoordinate,
            guidance: guidance,
            streets: streets,
            now: Fixtures.now,
            locale: Locale(identifier: "en_US")
        )
    }

    // MARK: Where a car is

    @Test func LeaderAheadOnTheRouteSaysDistanceAndStreet() {
        let answers = Self.Answers(streets: [Fixtures.agusID: "Ahmad Yani Street"])

        #expect(answers.WhereIsLeader() == "Agus is 1.2 km ahead, on Ahmad Yani Street.")
    }

    @Test func StreetNotKnownYetLeavesItOut() {
        #expect(Self.Answers().WhereIsLeader() == "Agus is 1.2 km ahead.")
    }

    @Test func CarBehindOnTheRouteIsBehind() {
        let answers = Self.Answers(budi: Self.OnRoute(0.5), citra: Self.OnRoute(0.4))

        #expect(answers.WhereIs(carID: Fixtures.citraID) == "Citra is 400 m behind.")
    }

    @Test func CarOffTheRouteIsAwayInAStraightLine() {
        let answers = Self.Answers(budi: Fixtures.startPoint.coordinate, citra: Self.NorthOfStart(404))

        #expect(answers.WhereIs(carID: Fixtures.citraID) == "Citra is 400 m away.")
    }

    @Test func CarWithin50MetresIsRightNextToYou() {
        let answers = Self.Answers(budi: Self.OnRoute(0.2), citra: Self.OnRoute(0.205))

        #expect(answers.WhereIs(carID: Fixtures.citraID) == "Citra is right next to you.")
    }

    @Test func OfflineCarSaysWhenItWasLastSeen() {
        let answers = Self.Answers { state in
            state.participants[0].lastSeenAt = Fixtures.now.addingTimeInterval(-180)
        }

        #expect(answers.WhereIsLeader() == "Agus is offline. Last seen 3 min ago.")
    }

    @Test func CarWithoutALocationIsNotKnownYet() {
        #expect(Self.Answers(agus: nil).WhereIsLeader() == "Agus's location isn't known yet.")
    }

    @Test func WithoutMyOwnLocationTheDistanceIsUnknown() {
        #expect(Self.Answers(budi: nil).WhereIsLeader() == "Your location isn't known yet.")
    }

    @Test func LeaderAskingForTheLeaderIsTheLeader() {
        #expect(Self.Answers(me: Fixtures.agusID).WhereIsLeader() == "You're the leader.")
    }

    @Test func AskingForYourOwnCarIsYou() {
        #expect(Self.Answers().WhereIs(carID: Fixtures.budiID) == "That's you.")
    }

    @Test func CarThatLeftTheTripIsNotOnTheTrip() {
        #expect(Self.Answers().WhereIs(carID: UUID()) == "That car isn't on this trip.")
    }

    @Test func UnnamedCarUsesItsGroupName() {
        let answers = Self.Answers { state in state.participants[2].displayName = "" }

        #expect(answers.WhereIs(carID: Fixtures.citraID) == "Car 3 is 400 m behind.")
    }

    // MARK: Is everyone with me

    @Test func EveryoneOnlineWithoutAlertsIsWithTheGroup() {
        #expect(Self.Answers().EveryoneWithMe() == "All 3 cars are with the group.")
    }

    @Test func CarOffTheRouteIsNamed() {
        let answers = Self.Answers { state in state.participants[2].alert = .offRoute }

        #expect(answers.EveryoneWithMe() == "2 of 3 cars are with the group. Citra is off the route.")
    }

    @Test func CarsAreNamedInTheOrderOfTheBanners() {
        let answers = Self.Answers(me: Fixtures.agusID) { state in
            state.participants[1].alert = .aheadOfLeader
            state.participants[2].lastSeenAt = Fixtures.now.addingTimeInterval(-300)
            state.participants.append(Self.Car(UUID(), "Dewi", at: Self.OnRoute(0.3)))
            state.participants[3].alert = .passedCheckpoint
        }

        let expected = "1 of 4 cars are with the group. "
            + "Dewi passed a checkpoint. Budi is ahead of the leader. Citra is offline."
        #expect(answers.EveryoneWithMe() == expected)
    }

    @Test func MyOwnAlertIsAboutMe() {
        let answers = Self.Answers { state in state.participants[1].alert = .offRoute }

        #expect(answers.EveryoneWithMe() == "2 of 3 cars are with the group. You're off the route.")
    }

    @Test func OfflineLeaderIsNotWithTheGroup() {
        let answers = Self.Answers { state in
            state.participants[0].lastSeenAt = Fixtures.now.addingTimeInterval(-300)
        }

        #expect(answers.EveryoneWithMe() == "2 of 3 cars are with the group. Agus is offline.")
    }

    @Test func ArrivedCarIsWithTheGroupWhateverItsLastAlert() {
        let answers = Self.Answers { state in
            state.participants[2].alert = .passedDestination
            state.participants[2].arrivedAtWaypointID = Fixtures.destination.id
        }

        #expect(answers.EveryoneWithMe() == "All 3 cars are with the group.")
    }

    @Test func OnlyCarInTheTripSaysSo() {
        let answers = Self.Answers(me: Fixtures.agusID) { state in
            state.participants = [state.participants[0]]
        }

        #expect(answers.EveryoneWithMe() == "You're the only car in the trip.")
    }

    // MARK: How long left

    @Test func TimeLeftNamesTheDestinationAndDistance() {
        let answers = Self.Answers(guidance: Self.Guidance(minutes: 14, kilometres: 12)) { state in
            state.trip.currentWaypointIndex = 2
        }

        #expect(answers.TimeLeft() == "14 min to Pakuwon mall, 12 km.")
    }

    @Test func TimeLeftWithoutDistanceLeavesItOut() {
        let answers = Self.Answers(guidance: Self.Guidance(minutes: 65, kilometres: nil)) { state in
            state.trip.currentWaypointIndex = 2
        }

        #expect(answers.TimeLeft() == "1 hr, 5 min to Pakuwon mall.")
    }

    @Test func UnvisitedCheckpointIsTheNextStop() {
        let answers = Self.Answers(budi: Self.OnRoute(0.5), guidance: Self.Guidance(minutes: 14, kilometres: 12))

        #expect(answers.TimeLeft() == "14 min to Pakuwon mall, 12 km. Next stop: Ciputra World, 2 km away.")
    }

    @Test func WithoutGuidanceTheTimeLeftIsUnknown() {
        #expect(Self.Answers().TimeLeft() == "The time left isn't known yet.")
    }

    private static func Guidance(minutes: Int, kilometres: Double?) -> TripMapGuidance {
        var guidance = Fixtures.Guidance(minutesLeft: minutes)
        guidance.distanceLeft = kilometres.map { Measurement(value: $0, unit: .kilometers) }
        return guidance
    }

    // MARK: Mute

    @Test(arguments: [
        (true, "Voice alerts are off. Banners still show on the map."),
        (false, "Voice alerts are on.")
    ])
    func MuteSaysTheNewState(isMuted: Bool, expected: String) {
        #expect(TripAnswers.Mute(isMuted: isMuted) == expected)
    }

    // MARK: I've arrived

    private static func NearDestination(_ metres: Double) -> Coordinate {
        let destination = Fixtures.destination.coordinate
        return Coordinate(latitude: destination.latitude + metres / 110_600, longitude: destination.longitude)
    }

    @Test func WithinOneKilometreSiriAsksFirst() throws {
        let answers = Self.Answers(budi: Self.NearDestination(203))

        guard case .ask(let confirmation) = answers.ArrivalCheck() else {
            Issue.record("Expected a question")
            return
        }
        #expect(confirmation.destinationName == "Pakuwon mall")
        #expect(confirmation.distance == Measurement(value: 200, unit: .meters))
        #expect(TripAnswers.ArrivalQuestion(confirmation) == "Arrived at Pakuwon mall?")
    }

    @Test func FurtherThanOneKilometreSaysHowFar() {
        let answers = Self.Answers(budi: Self.NearDestination(5_200))

        #expect(answers.ArrivalCheck()
            == .refuse("You're 5.2 km from Pakuwon mall. Say it again when you're closer."))
    }

    @Test func AlreadyArrivedSaysSo() {
        let answers = Self.Answers(budi: Self.NearDestination(10))

        #expect(answers.ArrivalCheck() == .refuse("You've already arrived."))
    }

    @Test func WithoutMyLocationArrivalIsRefused() {
        #expect(Self.Answers(budi: nil).ArrivalCheck() == .refuse("Your location isn't known yet."))
    }

    @Test(arguments: [
        (false, "You've arrived. Waiting for everyone to arrive."),
        (true, "Everyone has arrived!")
    ])
    func ArrivedSaysWhoIsStillComing(everyoneHasArrived: Bool, expected: String) {
        #expect(TripAnswers.Arrived(everyoneHasArrived: everyoneHasArrived) == expected)
    }

    @Test func StaticAnswersMatchTheSpec() {
        #expect(TripAnswers.noTrip == "No trip is on the road. Open Lezgo to start or join one.")
        #expect(TripAnswers.arrivalFailed == "Couldn't save your arrival. Check your connection and try again.")
    }
}

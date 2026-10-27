#if DEBUG
import Foundation
import Testing
@testable import Lezgo

struct SyncCheckViewModelTests {
    let store = InMemoryTripStore()
    let nathan: SyncCheckViewModel
    let iPhone: SyncCheckViewModel

    init() {
        let clock = { TripFixtures.now }
        nathan = SyncCheckViewModel(
            tripService: InMemoryTripService(store: store, userRecordID: "_nathan01", clock: clock),
            clock: clock
        )
        iPhone = SyncCheckViewModel(
            tripService: InMemoryTripService(store: store, userRecordID: "_iphone02", clock: clock),
            clock: clock
        )
    }

    @Test func CreateTripShowsTheRoomCodeWithMeAsLeader() async {
        await nathan.CreateTrip()

        #expect(nathan.state?.trip.roomCode.count == 6)
        #expect(nathan.isLeader)
        #expect(nathan.myParticipantID != nil)
        #expect(nathan.errorMessage == nil)
    }

    @Test func JoinWithTheRoomCodeAddsThisPhoneAsMember() async throws {
        await nathan.CreateTrip()
        iPhone.roomCodeInput = try #require(nathan.state?.trip.roomCode)

        await iPhone.JoinTrip()

        #expect(iPhone.state?.participants.count == 2)
        #expect(iPhone.isLeader == false)
    }

    @Test func WrongRoomCodeShowsTheError() async {
        iPhone.roomCodeInput = "000000"

        await iPhone.JoinTrip()

        #expect(iPhone.errorMessage == "No trip found with this code.")
        #expect(iPhone.state == nil)
    }

    @Test(arguments: ["", "8976", "89765a", "8976543"])
    func JoinNeedsExactlySixDigits(code: String) {
        iPhone.roomCodeInput = code

        #expect(iPhone.canJoin == false)
    }

    @Test func SixDigitsCanJoin() {
        iPhone.roomCodeInput = "897654"

        #expect(iPhone.canJoin)
    }

    @Test func LeaderHandsOverTheLead() async throws {
        await nathan.CreateTrip()
        iPhone.roomCodeInput = try #require(nathan.state?.trip.roomCode)
        await iPhone.JoinTrip()
        let iPhoneID = try #require(iPhone.myParticipantID)

        await nathan.HandOverLead(to: iPhoneID)

        #expect(nathan.isLeader == false)
        #expect(nathan.state?.leader?.id == iPhoneID)
    }

    @Test func LeaderStartsAndEndsTheTrip() async {
        await nathan.CreateTrip()

        await nathan.StartTrip()
        #expect(nathan.state?.trip.status == .inTrip)

        await nathan.EndTrip()
        #expect(nathan.state?.trip.status == .ended)
    }

    @Test func LogShowsWhoJoinedAndWhoLeads() async throws {
        await nathan.CreateTrip()
        let created = try #require(nathan.state)
        var joined = created
        joined.participants.append(TripFixtures.Participant())
        var handedOver = joined
        handedOver.trip.leaderParticipantID = TripFixtures.budiID

        nathan.Apply(joined)
        nathan.Apply(handedOver)

        let messages = nathan.log.map(\.message)
        #expect(messages.contains("Budi joined"))
        #expect(messages.contains("Budi is now the leader"))
        #expect(nathan.log.allSatisfy { $0.seenAt == TripFixtures.now })
    }

    @Test func LogShowsLeavingAndStatusChanges() async throws {
        await nathan.CreateTrip()
        let created = try #require(nathan.state)
        var withBudi = created
        withBudi.participants.append(TripFixtures.Participant())
        var started = withBudi
        started.trip.status = .inTrip
        started.participants.removeAll { $0.id == TripFixtures.budiID }

        nathan.Apply(withBudi)
        nathan.Apply(started)

        let messages = nathan.log.map(\.message)
        #expect(messages.contains("Budi left"))
        #expect(messages.contains("Trip is IN_TRIP"))
    }

    @Test func UnchangedStateAddsNothingToTheLog() async throws {
        await nathan.CreateTrip()
        let created = try #require(nathan.state)
        let logCount = nathan.log.count

        nathan.Apply(created)

        #expect(nathan.log.count == logCount)
    }

    @Test func MapOpensOnlyOnceTheTripIsOnTheRoad() async {
        await nathan.CreateTrip()
        #expect(nathan.canOpenMap == false)

        await nathan.StartTrip()
        #expect(nathan.canOpenMap)

        await nathan.EndTrip()
        #expect(nathan.canOpenMap == false)
    }
}
#endif

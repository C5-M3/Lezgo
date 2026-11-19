//
//  TripServiceSeatTests.swift
//  LezgoTests
//
//  Created by Oky Faishal on 16/11/26.
//

import CloudKit
import Foundation
import Testing
@testable import Lezgo

/// One iCloud account is in one trip at a time, for both implementations (ADR 0031).
struct TripServiceSeatTests {
    private let plan = TripPlanFixtures.tunjunganToPakuwon

    // MARK: One trip per account

    @Test(arguments: TripPhones.Kind.allCases)
    func AccountWithoutATripHasNoSeat(kind: TripPhones.Kind) async throws {
        let phones = SeatPhones(kind)

        #expect(try await phones.first.MyTrip() == nil)
    }

    @Test(arguments: TripPhones.Kind.allCases)
    func SecondTripOnTheSamePhoneIsRefused(kind: TripPhones.Kind) async throws {
        let phones = SeatPhones(kind)
        _ = try await phones.first.CreateTrip(plan: plan, profile: nil)

        await #expect(throws: TripServiceError.alreadyInTrip) {
            try await phones.first.CreateTrip(plan: plan, profile: nil)
        }
    }

    @Test(arguments: TripPhones.Kind.allCases)
    func SecondTripFromAnotherPhoneOfTheAccountIsRefused(kind: TripPhones.Kind) async throws {
        let phones = SeatPhones(kind)
        _ = try await phones.first.CreateTrip(plan: plan, profile: nil)

        await #expect(throws: TripServiceError.alreadyInTrip) {
            try await phones.second.CreateTrip(plan: plan, profile: nil)
        }
    }

    @Test(arguments: TripPhones.Kind.allCases)
    func JoiningAnotherTripWhileInATripIsRefused(kind: TripPhones.Kind) async throws {
        let phones = SeatPhones(kind)
        _ = try await phones.first.CreateTrip(plan: plan, profile: nil)
        let otherTrip = try await phones.other.CreateTrip(plan: plan, profile: nil)

        await #expect(throws: TripServiceError.alreadyInTrip) {
            try await phones.second.JoinTrip(roomCode: otherTrip.state.trip.roomCode, profile: nil)
        }
    }

    @Test(arguments: TripPhones.Kind.allCases)
    func RefusedTripLeavesTheOriginalSeatAlone(kind: TripPhones.Kind) async throws {
        let phones = SeatPhones(kind)
        let created = try await phones.first.CreateTrip(plan: plan, profile: nil)
        _ = try? await phones.second.CreateTrip(plan: plan, profile: nil)

        let mine = try await phones.first.MyTrip()

        #expect(mine?.state.trip.id == created.state.trip.id)
        #expect(mine?.myParticipantID == created.myParticipantID)
    }

    @Test(arguments: TripPhones.Kind.allCases)
    func TwoPhonesCreatingAtTheSameTimeCannotBothWin(kind: TripPhones.Kind) async {
        let phones = SeatPhones(kind)
        let plan = plan

        async let firstResult = Result { try await phones.first.CreateTrip(plan: plan, profile: nil) }
        async let secondResult = Result { try await phones.second.CreateTrip(plan: plan, profile: nil) }
        let results = await [firstResult, secondResult]

        #expect(results.count(where: { (try? $0.get()) != nil }) == 1)
        let refused = results.compactMap { result -> TripServiceError? in
            if case let .failure(error) = result { return error as? TripServiceError }
            return nil
        }
        #expect(refused == [.alreadyInTrip])
    }

    // MARK: The seat on every phone of the account

    @Test(arguments: TripPhones.Kind.allCases)
    func AnotherPhoneOfTheAccountFindsTheTrip(kind: TripPhones.Kind) async throws {
        let phones = SeatPhones(kind)
        let created = try await phones.first.CreateTrip(plan: plan, profile: nil)

        let found = try #require(try await phones.second.MyTrip())

        #expect(found.state.trip.id == created.state.trip.id)
        #expect(found.myParticipantID == created.myParticipantID)
    }

    @Test(arguments: TripPhones.Kind.allCases)
    func AnotherAccountDoesNotSeeTheTrip(kind: TripPhones.Kind) async throws {
        let phones = SeatPhones(kind)
        _ = try await phones.first.CreateTrip(plan: plan, profile: nil)

        #expect(try await phones.other.MyTrip() == nil)
    }

    @Test(arguments: TripPhones.Kind.allCases)
    func JoiningTheSameTripFromAnotherPhoneKeepsOneCar(kind: TripPhones.Kind) async throws {
        let phones = SeatPhones(kind)
        let created = try await phones.first.CreateTrip(plan: plan, profile: nil)

        let taken = try await phones.second.JoinTrip(roomCode: created.state.trip.roomCode, profile: nil)

        #expect(taken.myParticipantID == created.myParticipantID)
        #expect(taken.state.participants.count == 1)
    }

    @Test(arguments: TripPhones.Kind.allCases)
    func AccountTokenIsTheSameOnEveryPhoneAndHidesTheAccount(kind: TripPhones.Kind) async throws {
        let phones = SeatPhones(kind)

        let token = try await phones.first.AccountID()

        #expect(token == (try await phones.second.AccountID()))
        #expect(token != (try await phones.other.AccountID()))
        #expect(token.contains("agus0001") == false)
    }

    // MARK: The newest phone wins

    @Test(arguments: TripPhones.Kind.allCases)
    func OlderPhoneIsToldWhenAnotherPhoneJoins(kind: TripPhones.Kind) async throws {
        let phones = SeatPhones(kind)
        let created = try await phones.first.CreateTrip(plan: plan, profile: nil)
        let tripID = created.state.trip.id
        let first = phones.first

        let wasTold = Task { @MainActor in await Finishes { await first.SeatTakenOver(tripID: tripID) } }
        try await Task.sleep(for: .milliseconds(50))
        _ = try await phones.second.JoinTrip(roomCode: created.state.trip.roomCode, profile: nil)

        #expect(await wasTold.value)
    }

    @Test(arguments: TripPhones.Kind.allCases)
    func PhoneThatStillHoldsTheSeatIsNeverTold(kind: TripPhones.Kind) async throws {
        let phones = SeatPhones(kind)
        let created = try await phones.first.CreateTrip(plan: plan, profile: nil)
        let tripID = created.state.trip.id
        let first = phones.first

        let wasTold = await Finishes(within: .milliseconds(300)) { await first.SeatTakenOver(tripID: tripID) }

        #expect(wasTold == false)
    }

    @Test(arguments: TripPhones.Kind.allCases)
    func PhoneThatTakesTheSeatBackTellsTheOtherOne(kind: TripPhones.Kind) async throws {
        let phones = SeatPhones(kind)
        let created = try await phones.first.CreateTrip(plan: plan, profile: nil)
        let tripID = created.state.trip.id
        let roomCode = created.state.trip.roomCode
        _ = try await phones.second.JoinTrip(roomCode: roomCode, profile: nil)
        let second = phones.second

        let wasTold = Task { @MainActor in await Finishes { await second.SeatTakenOver(tripID: tripID) } }
        try await Task.sleep(for: .milliseconds(50))
        _ = try await phones.first.JoinTrip(roomCode: roomCode, profile: nil)

        #expect(await wasTold.value)
    }

    /// The seat is one per account, so a new trip on this same phone changes it too: that is not another phone.
    @Test(arguments: TripPhones.Kind.allCases)
    func NewTripOnTheSamePhoneIsNotATakeoverOfTheOldTrip(kind: TripPhones.Kind) async throws {
        let phones = SeatPhones(kind)
        let first = phones.first
        let oldTrip = try await first.CreateTrip(plan: plan, profile: nil)
        let oldTripID = oldTrip.state.trip.id

        let wasTold = Task { @MainActor in
            await Finishes(within: .milliseconds(300)) { await first.SeatTakenOver(tripID: oldTripID) }
        }
        try await Task.sleep(for: .milliseconds(50))
        try await first.EndTrip(tripID: oldTripID, by: oldTrip.myParticipantID)
        _ = try await first.CreateTrip(plan: plan, profile: nil)

        #expect(await wasTold.value == false)
    }

    // MARK: Resuming from Draft Trip

    @Test(arguments: TripPhones.Kind.allCases)
    func ResumingTakesTheSeatBackWithoutAddingACar(kind: TripPhones.Kind) async throws {
        let phones = SeatPhones(kind)
        let created = try await phones.first.CreateTrip(plan: plan, profile: nil)
        let tripID = created.state.trip.id
        _ = try await phones.second.JoinTrip(roomCode: created.state.trip.roomCode, profile: nil)
        let second = phones.second

        let wasTold = Task { @MainActor in await Finishes { await second.SeatTakenOver(tripID: tripID) } }
        try await Task.sleep(for: .milliseconds(50))
        let resumed = try await phones.first.ResumeTrip(tripID: tripID, participantID: created.myParticipantID)

        #expect(resumed.myParticipantID == created.myParticipantID)
        #expect(resumed.state.participants.count == 1)
        #expect(await wasTold.value)
    }

    @Test(arguments: TripPhones.Kind.allCases)
    func RemovedMemberCannotResumeTheTrip(kind: TripPhones.Kind) async throws {
        let phones = SeatPhones(kind)
        let created = try await phones.other.CreateTrip(plan: plan, profile: nil)
        let tripID = created.state.trip.id
        let joined = try await phones.first.JoinTrip(roomCode: created.state.trip.roomCode, profile: nil)
        try await phones.other.RemoveParticipants([joined.myParticipantID], tripID: tripID, by: created.myParticipantID)

        await #expect(throws: TripServiceError.notFound) {
            try await phones.first.ResumeTrip(tripID: tripID, participantID: joined.myParticipantID)
        }
        #expect(try await phones.other.FetchTrip(tripID: tripID).participants.count == 1)
    }

    @Test(arguments: TripPhones.Kind.allCases)
    func EndedTripCannotBeResumed(kind: TripPhones.Kind) async throws {
        let phones = SeatPhones(kind)
        let created = try await phones.first.CreateTrip(plan: plan, profile: nil)
        try await phones.first.EndTrip(tripID: created.state.trip.id, by: created.myParticipantID)

        await #expect(throws: TripServiceError.tripEnded) {
            try await phones.second.ResumeTrip(tripID: created.state.trip.id, participantID: created.myParticipantID)
        }
    }

    // MARK: Stale seats

    @Test(arguments: TripPhones.Kind.allCases)
    func EndedTripFreesTheSeat(kind: TripPhones.Kind) async throws {
        let phones = SeatPhones(kind)
        let created = try await phones.first.CreateTrip(plan: plan, profile: nil)
        try await phones.first.EndTrip(tripID: created.state.trip.id, by: created.myParticipantID)

        #expect(try await phones.second.MyTrip() == nil)
        _ = try await phones.second.CreateTrip(plan: plan, profile: nil)
    }

    @Test(arguments: TripPhones.Kind.allCases)
    func MemberWhoExitsCanStartAnotherTrip(kind: TripPhones.Kind) async throws {
        let phones = SeatPhones(kind)
        let created = try await phones.other.CreateTrip(plan: plan, profile: nil)
        let joined = try await phones.first.JoinTrip(roomCode: created.state.trip.roomCode, profile: nil)
        try await phones.first.ExitTrip(tripID: created.state.trip.id, participantID: joined.myParticipantID)

        #expect(try await phones.second.MyTrip() == nil)
        _ = try await phones.second.CreateTrip(plan: plan, profile: nil)
    }

    @Test(arguments: TripPhones.Kind.allCases)
    func MemberWhoWasRemovedCanStartAnotherTrip(kind: TripPhones.Kind) async throws {
        let phones = SeatPhones(kind)
        let created = try await phones.other.CreateTrip(plan: plan, profile: nil)
        let joined = try await phones.first.JoinTrip(roomCode: created.state.trip.roomCode, profile: nil)
        try await phones.other.RemoveParticipants(
            [joined.myParticipantID],
            tripID: created.state.trip.id,
            by: created.myParticipantID
        )

        #expect(try await phones.first.MyTrip() == nil)
        _ = try await phones.first.CreateTrip(plan: plan, profile: nil)
    }

    @Test(arguments: TripPhones.Kind.allCases)
    func TripThatReturnsToTheLobbyKeepsTheSeat(kind: TripPhones.Kind) async throws {
        let phones = SeatPhones(kind)
        let created = try await phones.first.CreateTrip(plan: plan, profile: nil)
        let member = try await phones.other.JoinTrip(roomCode: created.state.trip.roomCode, profile: nil)
        try await phones.first.StartTrip(tripID: created.state.trip.id, by: created.myParticipantID)

        let mine = try #require(try await phones.second.MyTrip())

        #expect(mine.state.trip.status == .inTrip)
        #expect(member.state.trip.id == mine.state.trip.id)
    }

    // MARK: Trips made before the seat existed

    @Test func MemberOfATripWithoutASeatGetsTheSeatWhenJoiningAgain() async throws {
        let phones = SeatPhones(.live)
        let created = try await phones.first.CreateTrip(plan: plan, profile: nil)
        try #require(phones.server).Delete(SeatPhones.seatRecordID)
        #expect(try await phones.second.MyTrip() == nil)

        let joined = try await phones.second.JoinTrip(roomCode: created.state.trip.roomCode, profile: nil)

        #expect(joined.myParticipantID == created.myParticipantID)
        #expect(try await phones.first.MyTrip()?.state.trip.id == created.state.trip.id)
    }

    @Test func SeatIsNeverReadAsTheTripsFootprint() async throws {
        let phones = SeatPhones(.live)
        let created = try await phones.first.CreateTrip(plan: plan, profile: nil)

        let state = try await phones.second.FetchTrip(tripID: created.state.trip.id)

        #expect(state.trail.isEmpty)
    }
}

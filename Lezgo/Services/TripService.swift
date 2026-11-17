//
//  TripService.swift
//  Lezgo
//
//  Created by Nathan Sudiara on 26/10/26.
//

import Foundation

/// Every trip operation the app needs, in one place (ADR 0017).
///
/// - `LiveTripService` syncs trips between phones through CloudKit (ADR 0014); the app uses it.
/// - `InMemoryTripService` keeps trips in memory for previews, `DebugScreen` and tests.
/// - `CloudKit/TripSync.md` explains every operation, how sync works, and how a screen uses the service.
/// - A view reads the service with `@Environment(\.tripService)` and passes it to its view model's initializer.
/// - Every call that changes something throws `TripServiceError`. Leader-only actions take the caller's
///   participant ID and throw `.notAllowed` when the caller is not the leader.
/// - Changing this protocol changes every screen: tell the team, and update both implementations in one PR.
protocol TripService {
    // MARK: Create, join and read

    /// Creates a trip in `LOBBY` with a new 6-digit room code, the plan as route version 1, and the caller as leader.
    /// - Throws: `.alreadyInTrip` when this iCloud account is in another open trip (ADR 0031).
    /// - Parameter profile: the leader's name and car; `nil` uses "Member" plus the end of the iCloud user ID.
    func CreateTrip(plan: TripPlan, profile: ParticipantProfile?) async throws -> TripSession

    /// Joins the trip with this room code as a member. Joining again with the same iCloud account returns the
    /// existing participant instead of adding a second car.
    /// - Parameter profile: the member's name and car; `nil` uses "Member" plus the end of the iCloud user ID.
    /// Joining the trip this account is already in from another phone takes the account's place over: the other phone
    /// is told through `SeatTakenOver` (ADR 0031).
    /// - Throws: `.notFound` for an unknown code, `.tripEnded` for an `ENDED` or `CANCELLED` trip,
    ///   `.tripAlreadyStarted` for an `IN_TRIP` trip when this account is not in it yet (a started trip takes no new
    ///   people), `.alreadyInTrip` when this account is in another open trip.
    func JoinTrip(roomCode: String, profile: ParticipantProfile?) async throws -> TripSession

    /// The open trip this iCloud account is in, with this account's participant, or `nil` when it is in none
    /// (ADR 0031). Every phone of the account gets the same answer, so the app can open on Home or Draft Trip after
    /// a restart.
    func MyTrip() async throws -> TripSession?

    /// Takes this account's place in the trip back on this phone, for "Continue" on Draft Trip (ADR 0031). Unlike
    /// `JoinTrip` it never adds a car: a member who was removed is refused, so Continue cannot undo a removal.
    /// - Throws: `.notFound` when the trip or this participant is gone, `.tripEnded` for an `ENDED` or `CANCELLED`
    ///   trip, `.alreadyInTrip` when this account's seat is for another trip.
    func ResumeTrip(tripID: UUID, participantID: UUID) async throws -> TripSession

    /// Returns when another phone of this account has taken this phone's place in the trip, and never returns while
    /// this phone still holds it. Cancel the task to stop listening. Call it after `CreateTrip` or `JoinTrip` on this
    /// service; for a trip this service did not join it waits until cancelled (ADR 0031).
    func SeatTakenOver(tripID: UUID) async

    /// A short, stable name for this iCloud account that does not show the account, to tell whose trip a saved
    /// summary is (ADR 0031).
    func AccountID() async throws -> String

    /// The trip as it is now, for example to check a saved trip when the app opens (US-03).
    func FetchTrip(tripID: UUID) async throws -> TripState

    /// The trip right away, then again after every change by any phone. The live service fetches it every second.
    /// The stream keeps going while the network is down and finishes only when the listening task is cancelled.
    /// A participant missing from a new state has left or was removed.
    func TripUpdates(tripID: UUID) -> AsyncStream<TripState>

    // MARK: Leader actions in the Trip Room

    /// Sets the trip `IN_TRIP` with `startedAt` and moves `currentWaypointIndex` to 1. Only from `LOBBY`.
    func StartTrip(tripID: UUID, by leaderID: UUID) async throws

    /// Removes members from the trip. The leader cannot remove themselves.
    func RemoveParticipants(_ participantIDs: [UUID], tripID: UUID, by leaderID: UUID) async throws

    /// Makes `newLeaderID` the leader, but only if `expectedLeaderID` still leads (a conditional save).
    /// Members also call this when the leader has been offline for 5 minutes (US-06).
    /// - Throws: `.conflict` when someone else changed the leader first.
    func SetLeader(_ newLeaderID: UUID, tripID: UUID, replacing expectedLeaderID: UUID) async throws

    // MARK: Leave and end

    /// A member leaves: their participant is deleted. The leader must hand over the lead or end the trip instead.
    func ExitTrip(tripID: UUID, participantID: UUID) async throws

    /// Ends the trip for everyone: `CANCELLED` from `LOBBY`, `ENDED` from `IN_TRIP`, with `endedAt`.
    func EndTrip(tripID: UUID, by leaderID: UUID) async throws

    // MARK: On the road

    /// Saves this phone's location, speed, motion state and `lastSeenAt` (about once per second).
    /// For a participant who was removed or left, the update is ignored: it never adds them back to the trip.
    func UpdateLocation(_ update: LocationUpdate, participantID: UUID, tripID: UUID) async throws

    /// Saves this phone's current formation alert. Members only; the leader never has one.
    func SetAlert(_ alert: FormationAlert, participantID: UUID, tripID: UUID) async throws

    /// Saves the way back of a member who left the group's road, for the leader's map; empty clears it. Members only.
    func SetWayBack(_ wayBack: [Coordinate], participantID: UUID, tripID: UUID) async throws
    /// "I've Arrived": the leader or a member says they reached the trip's current destination
    /// (`Participant.arrivedAtWaypointID`). Throws `.notAllowed` before the trip starts or for another waypoint.
    func MarkArrived(at destinationID: UUID, participantID: UUID, tripID: UUID) async throws

    /// Moves the trip past a checkpoint. Only forward: a lower or equal index changes nothing.
    func AdvanceCheckpoint(to waypointIndex: Int, tripID: UUID, by leaderID: UUID) async throws

    /// Replaces the route on the road (automatic reroute or Edit Route) as `routeVersion + 1`, and sets
    /// `currentWaypointIndex` to 1, because the new plan starts at the leader's position.
    func SaveRoute(_ plan: TripPlan, tripID: UUID, by leaderID: UUID) async throws

    /// Replaces the road the leader has driven, their footprint (`TripState.trail`), so the members behind can follow
    /// it. The leader's phone saves it every few seconds while driving.
    func SaveTrail(_ trail: [Coordinate], tripID: UUID, by leaderID: UUID) async throws

    /// New Destination after arriving: replaces the route as `routeVersion + 1`, sets the trip back to `LOBBY`
    /// with `currentWaypointIndex` 0, and keeps the room code and members.
    func StartNewDestination(_ plan: TripPlan, tripID: UUID, by leaderID: UUID) async throws

    // MARK: Profile

    /// Changes this person's name and car in the trip.
    func UpdateProfile(_ profile: ParticipantProfile, participantID: UUID, tripID: UUID) async throws
}

//
//  TripRoomViewModel.swift
//  Lezgo
//
//  Created by Oky Faishal on 26/10/26.
//

import CoreLocation
import Foundation
import Observation

/// View model managing state and actions for the Trip Room screen.
@Observable
@MainActor
final class TripRoomViewModel {
    private(set) var state: TripState?
    private let tripService: any TripService
    /// Sends this phone's position while the room is open, so the group sees who is at the start point; `nil` in
    /// previews and tests that do not need it.
    private let locationSharer: LocationSharer?
    /// The trip saved on this phone, cleared once this person has left so Home no longer offers it.
    private let activeTripStorage: any ActiveTripStorage
    let tripID: UUID
    let myParticipantID: UUID

    var isSelectionMode: Bool
    var selectedParticipantIds: Set<UUID>
    var errorMessage: String?
    var wasRemovedFromTrip: Bool = false
    /// Set when the trip was cancelled or ended by the leader while I am a member, so the room tells me and closes.
    var wasEndedByLeader = false
    private(set) var hasTripStarted = false
    private(set) var isStartingTrip = false
    private(set) var isSavingProfile = false
    /// `true` while an exit request is on its way; Exit is disabled meanwhile.
    private(set) var isLeaving = false
    /// Set once leaving succeeded, so the room closes only for the request that actually left.
    private(set) var hasLeft = false
    /// Shown inside the edit sheet, which stays open when the save fails so the typed name and car are kept.
    var profileErrorMessage: String?

    var roomCode: String {
        state?.trip.roomCode ?? ""
    }

    var waypoints: [Waypoint] {
        state?.waypoints ?? []
    }

    var startPoint: Waypoint? {
        waypoints.first(where: { $0.kind == .start })
    }

    var participants: [Participant] {
        state?.participants ?? []
    }

    var isCurrentUserLeader: Bool {
        guard let state else { return false }
        return state.trip.leaderParticipantID == myParticipantID
    }

    var tripStatus: TripStatus {
        state?.trip.status ?? .lobby
    }

    var canStartTrip: Bool {
        guard isCurrentUserLeader, !isStartingTrip, !hasTripStarted, let state else { return false }
        return state.participants.count > 1
    }

    var isEveryoneReady: Bool {
        guard !participants.isEmpty else { return false }
        return participants.allSatisfy { IsParticipantReady($0) }
    }

    /// What Exit asks first (`specs/UserStories.md` → US-07, "Leave and end").
    var leaveConfirmation: LeaveConfirmation {
        isCurrentUserLeader ? .endTripForEveryone : .exitRoom
    }

    var startTripConfirmationTitle: String {
        isEveryoneReady
            ? "Start trip?"
            : "Some participants are not yet ready, are you sure you want to start the trip?"
    }

    var areAllMembersSelected: Bool {
        guard let state else { return false }
        let memberIds = state.participants.filter { !$0.IsLeader(in: state.trip) }.map(\.id)
        return !memberIds.isEmpty && selectedParticipantIds.count == memberIds.count
    }

    var canRemove: Bool { !selectedParticipantIds.isEmpty }

    /// The leader can swipe every row to "Kick", their own too, where `CanKick` keeps it disabled (US-05).
    var showsKickSwipe: Bool { isCurrentUserLeader && !isSelectionMode }

    /// The leader can swipe every row to "Set Lead", their own too, where `CanSetLeader` keeps it disabled (US-05).
    var showsSetLeaderSwipe: Bool { isCurrentUserLeader && !isSelectionMode }

    var selectAllButtonTitle: String {
        areAllMembersSelected ? "Deselect all" : "Select all"
    }

    var removeConfirmationTitle: String {
        guard let state else { return "Remove participants from the trip?" }
        let selected = state.participants.filter { selectedParticipantIds.contains($0.id) }
        guard let first = selected.first else { return "Remove participants from the trip?" }
        let remaining = selected.count - 1
        if remaining == 0 {
            return "Remove \(first.displayName) from the trip?"
        } else if remaining == 1 {
            return "Remove \(first.displayName) and 1 other from the trip?"
        } else {
            return "Remove \(first.displayName) and \(remaining) others from the trip?"
        }
    }

    var inviteURL: URL {
        InviteLink.Make(roomCode: roomCode) ?? URL(fileURLWithPath: "/")
    }

    /// The room code is empty until the first snapshot arrives, and a link without six digits cannot be joined.
    var canShareInvite: Bool {
        Trip.IsValidRoomCode(roomCode)
    }

    /// The text sent with the invite link, so the code can also be typed in by hand.
    var shareMessage: String {
        String(localized: .tripRoomShareMessage(roomCode))
    }

    init(
        tripService: any TripService,
        tripID: UUID,
        myParticipantID: UUID,
        initialState: TripState? = nil,
        activeTripStorage: (any ActiveTripStorage)? = nil,
        locationSharer: LocationSharer? = nil
    ) {
        self.tripService = tripService
        self.locationSharer = locationSharer
        self.activeTripStorage = activeTripStorage ?? UserDefaultsActiveTripStorage()
        self.tripID = tripID
        self.myParticipantID = myParticipantID
        self.state = initialState
        self.isSelectionMode = false
        self.selectedParticipantIds = []
        if let initialState, initialState.trip.status == .inTrip {
            let isLeader = initialState.trip.leaderParticipantID == myParticipantID
            let isStillInTrip = initialState.participants.contains(where: { $0.id == myParticipantID })
            if isLeader || isStillInTrip {
                self.hasTripStarted = true
            }
        }
    }

    func StartTrip() async throws {
        // `canStartTrip` is false while a start is saving or after it, so a second tap does nothing.
        guard canStartTrip else { return }
        isStartingTrip = true
        defer { isStartingTrip = false }
        try await tripService.StartTrip(tripID: tripID, by: myParticipantID)
        hasTripStarted = true
    }

    func ToggleSelectionMode() {
        guard isCurrentUserLeader else { return }
        isSelectionMode.toggle()
        if !isSelectionMode { selectedParticipantIds.removeAll() }
    }

    func ToggleParticipantSelection(id: UUID) {
        guard let state,
              let participant = state.participants.first(where: { $0.id == id }),
              !participant.IsLeader(in: state.trip) else { return }
        if selectedParticipantIds.contains(id) {
            selectedParticipantIds.remove(id)
        } else {
            selectedParticipantIds.insert(id)
        }
    }

    func SelectAll() {
        guard let state else { return }
        let memberIds = state.participants.filter { !$0.IsLeader(in: state.trip) }.map(\.id)
        selectedParticipantIds = (selectedParticipantIds.count == memberIds.count) ? [] : Set(memberIds)
    }

    func RemoveSelectedParticipants() async throws {
        guard isCurrentUserLeader, canRemove else { return }
        let ids = Array(selectedParticipantIds)
        try await tripService.RemoveParticipants(ids, tripID: tripID, by: myParticipantID)
        selectedParticipantIds.removeAll()
        isSelectionMode = false
    }

    func RemoveParticipant(id: UUID) async throws {
        guard isCurrentUserLeader,
              let state,
              let target = state.participants.first(where: { $0.id == id }),
              !target.IsLeader(in: state.trip) else { return }
        try await tripService.RemoveParticipants([id], tripID: tripID, by: myParticipantID)
        selectedParticipantIds.remove(id)
    }

    func RemoveParticipantConfirmationTitle(for participant: Participant) -> String {
        "Remove \(participant.displayName) from the trip?"
    }

    func CanKick(participant: Participant) -> Bool {
        guard let state, isCurrentUserLeader, !isSelectionMode else { return false }
        return !participant.IsLeader(in: state.trip)
    }

    func CanSetLeader(participant: Participant) -> Bool {
        CanKick(participant: participant)
    }

    func SetLeader(to participant: Participant) async throws {
        guard isCurrentUserLeader,
              let currentLeaderID = state?.trip.leaderParticipantID,
              participant.id != currentLeaderID else { return }
        try await tripService.SetLeader(participant.id, tripID: tripID, replacing: currentLeaderID)
    }

    /// Hands the lead over after the leader confirmed, and shows the service's sentence when the save fails, for
    /// example `.conflict` when someone else changed the leader first.
    func HandOverLead(to participant: Participant) async {
        do {
            try await SetLeader(to: participant)
        } catch {
            ShowError(error)
        }
    }

    func SetLeaderConfirmationTitle(for participant: Participant) -> String {
        "Set \(participant.displayName) as Trip Leader?"
    }

    /// Shows a failed call in the error alert. `TripServiceError` is not a `LocalizedError`, so
    /// `localizedDescription` would only say "The operation couldn't be completed".
    func ShowError(_ error: any Error) {
        errorMessage = String(localized: TripServiceError(cloudKitError: error).message)
    }

    func CanEdit(participant: Participant) -> Bool {
        !isSelectionMode && participant.id == myParticipantID
    }

    func UpdateProfile(displayName: String, carDescription: String) async throws {
        let profile = ParticipantProfile(displayName: displayName, carDescription: carDescription)
        try await tripService.UpdateProfile(profile, participantID: myParticipantID, tripID: tripID)
    }

    /// Saves my profile for the edit sheet. Returns `true` only when the save succeeded, so the sheet closes then
    /// and stays open with `profileErrorMessage` otherwise. A second tap while saving is ignored.
    func SaveProfile(displayName: String, carDescription: String) async -> Bool {
        guard !isSavingProfile else { return false }
        isSavingProfile = true
        defer { isSavingProfile = false }
        do {
            try await UpdateProfile(displayName: displayName, carDescription: carDescription)
            profileErrorMessage = nil
            return true
        } catch let error as TripServiceError {
            profileErrorMessage = String(localized: error.message)
        } catch {
            profileErrorMessage = String(localized: TripServiceError(cloudKitError: error).message)
        }
        return false
    }

    /// A member leaves the trip; the leader cancels it for everyone. The trip is cleared from this phone only after
    /// the request succeeded, so a failure leaves the person in the room with their trip still saved.
    func LeaveTrip() async throws {
        guard !isLeaving, !hasLeft else { return }
        isLeaving = true
        defer { isLeaving = false }
        if isCurrentUserLeader {
            try await tripService.EndTrip(tripID: tripID, by: myParticipantID)
        } else {
            try await tripService.ExitTrip(tripID: tripID, participantID: myParticipantID)
        }
        activeTripStorage.ClearActiveTrip()
        hasLeft = true
    }

    func IsLeader(participant: Participant) -> Bool {
        guard let state else { return false }
        return participant.IsLeader(in: state.trip)
    }

    func IsParticipantReady(_ participant: Participant, at date: Date = .now) -> Bool {
        guard participant.IsOnline(at: date),
              let startCoord = startPoint?.coordinate,
              let participantCoord = participant.coordinate else { return false }
        let startLocation = CLLocation(latitude: startCoord.latitude, longitude: startCoord.longitude)
        let participantLocation = CLLocation(latitude: participantCoord.latitude, longitude: participantCoord.longitude)
        return startLocation.distance(from: participantLocation) <= 100
    }

    /// The confirmation Exit shows.
    enum LeaveConfirmation: Hashable {
        /// A member, or a leader who handed over the lead: "Exit the room?"
        case exitRoom
        /// The leader: the trip is cancelled for everyone.
        case endTripForEveryone
    }
}

// MARK: Following the trip

extension TripRoomViewModel {
    /// `true` while Precise Location is off: nobody can tell whether this car is at the start point.
    var isLocationImprecise: Bool {
        locationSharer?.isLocationImprecise ?? false
    }

    /// Follows the trip until the room closes, and shares this phone's position meanwhile (US-04, "Ready").
    func Listen() async {
        await withTaskGroup(of: Void.self) { group in
            if let locationSharer {
                group.addTask { await locationSharer.Run() }
            }
            await FollowTrip()
            group.cancelAll()
        }
    }

    private func FollowTrip() async {
        for await newState in tripService.TripUpdates(tripID: tripID) {
            let isStillInTrip = newState.participants.contains(where: { $0.id == myParticipantID })

            state = newState

            // No earlier snapshot is needed: I joined this trip, so any snapshot without me means I was removed,
            // even the first one (for example when I was removed before the room finished opening). The update that
            // follows my own exit can arrive before the request returns, so leaving on purpose is not a removal.
            if !isStillInTrip && !isCurrentUserLeader && !isLeaving && !hasLeft {
                wasRemovedFromTrip = true
                activeTripStorage.ClearActiveTrip()
            }

            // The leader who ended the trip leaves through Exit, so only the members are told.
            if !newState.trip.status.isOpen && !isCurrentUserLeader && !isLeaving && !hasLeft && !wasRemovedFromTrip {
                wasEndedByLeader = true
                activeTripStorage.ClearActiveTrip()
            }

            // Only someone still in the trip moves to the map: a member who is exiting or has exited is gone from
            // the participants, but is not removed, so the check above does not catch them.
            if !wasRemovedFromTrip && !isLeaving && !hasLeft
                && (isStillInTrip || isCurrentUserLeader)
                && newState.trip.status == .inTrip {
                hasTripStarted = true
            }

            if !isCurrentUserLeader && isSelectionMode {
                isSelectionMode = false
                selectedParticipantIds.removeAll()
            }
        }
    }
}

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
    let tripID: UUID
    let myParticipantID: UUID

    var isSelectionMode: Bool
    var selectedParticipantIds: Set<UUID>
    var errorMessage: String?
    var wasRemovedFromTrip: Bool = false
    private(set) var isSavingProfile = false
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
        guard isCurrentUserLeader, let state else { return false }
        return state.participants.count > 1
    }

    var isEveryoneReady: Bool {
        guard !participants.isEmpty else { return false }
        return participants.allSatisfy { IsParticipantReady($0) }
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
        URL(string: "lezgo://join?code=\(roomCode)") ?? URL(fileURLWithPath: "/")
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
        initialState: TripState? = nil
    ) {
        self.tripService = tripService
        self.tripID = tripID
        self.myParticipantID = myParticipantID
        self.state = initialState
        self.isSelectionMode = false
        self.selectedParticipantIds = []
    }

    func Listen() async {
        for await newState in tripService.TripUpdates(tripID: tripID) {
            let isStillInTrip = newState.participants.contains(where: { $0.id == myParticipantID })

            state = newState

            // No earlier snapshot is needed: I joined this trip, so any snapshot without me means I was removed,
            // even the first one (for example when I was removed before the room finished opening).
            if !isStillInTrip && !isCurrentUserLeader {
                wasRemovedFromTrip = true
            }

            if !isCurrentUserLeader && isSelectionMode {
                isSelectionMode = false
                selectedParticipantIds.removeAll()
            }
        }
    }

    func StartTrip() async throws {
        guard isCurrentUserLeader, canStartTrip else { return }
        try await tripService.StartTrip(tripID: tripID, by: myParticipantID)
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

    func LeaveTrip() async throws {
        if isCurrentUserLeader {
            try await tripService.EndTrip(tripID: tripID, by: myParticipantID)
        } else {
            try await tripService.ExitTrip(tripID: tripID, participantID: myParticipantID)
        }
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
}

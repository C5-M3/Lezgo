//
//  TripRoomViewModel.swift
//  Lezgo
//
//  Created by Oky Faishal on 26/10/26.
//

import Foundation
import Observation

/// View model managing state and actions for the Trip Room screen.
@Observable
@MainActor
public final class TripRoomViewModel {
    public enum TripStatus: Equatable, Sendable {
        case waiting
        case inTrip
        case cancelled
    }

    public enum RouteStopKind: Equatable, Sendable {
        case start
        case checkpoint
        case destination

        public var accessibilityPrefix: String {
            switch self {
            case .start: return "Starting point"
            case .checkpoint: return "Checkpoint"
            case .destination: return "Destination"
            }
        }

        public var iconName: String {
            switch self {
            case .start: return "house.fill"
            case .checkpoint: return "circle.fill"
            case .destination: return "mappin.and.ellipse"
            }
        }
    }

    public struct RouteStop: Identifiable, Equatable, Hashable, Sendable {
        public let id: UUID
        public var name: String
        public var kind: RouteStopKind

        public init(id: UUID = UUID(), name: String, kind: RouteStopKind) {
            self.id = id
            self.name = name
            self.kind = kind
        }
    }

    public var roomCode: String
    public var routeStops: [RouteStop]
    public var participants: [Participant]
    public var isCurrentUserLeader: Bool
    public var currentUserId: UUID
    public var isSelectionMode: Bool
    public var selectedParticipantIds: Set<UUID>
    public var tripStatus: TripStatus

    public var areAllMembersSelected: Bool {
        let memberIds = participants.filter { !$0.isLeader }.map(\.id)
        return !memberIds.isEmpty && selectedParticipantIds.count == memberIds.count
    }

    public var canRemove: Bool { !selectedParticipantIds.isEmpty }

    public var selectAllButtonTitle: String {
        areAllMembersSelected ? "Deselect all" : "Select all"
    }

    public var removeConfirmationTitle: String {
        let selected = participants.filter { selectedParticipantIds.contains($0.id) }
        guard let first = selected.first else { return "Remove participants from the trip?" }
        let remaining = selected.count - 1
        if remaining == 0 {
            return "Remove \(first.name) from the trip?"
        } else if remaining == 1 {
            return "Remove \(first.name) and 1 other from the trip?"
        } else {
            return "Remove \(first.name) and \(remaining) others from the trip?"
        }
    }

    public var inviteURL: URL {
        URL(string: "lezgo://join?code=\(roomCode)") ?? URL(fileURLWithPath: "/")
    }

    public static var defaultDummyParticipants: [Participant] {
        [
            Participant(name: "Faishal (You)", description: "Innova Hitam - H 1234 CD", isLeader: true),
            Participant(name: "Matthew", description: "Civic Putih - W 8888 XY", isLeader: false),
            Participant(name: "Farr", description: "HR-V Abu-abu - L 4321 EF", isLeader: false),
            Participant(name: "Nat", description: "Ioniq 5 Silver - DK 5678 GH", isLeader: false),
            Participant(name: "Zal", description: "Ioniq 7 Black - H 28947 HUO", isLeader: false)
        ]
    }

    public init(
        roomCode: String = "5JUV83",
        routeStops: [RouteStop]? = nil,
        participants: [Participant]? = nil,
        isCurrentUserLeader: Bool = true,
        currentUserId: UUID? = nil
    ) {
        self.roomCode = roomCode
        self.routeStops = routeStops ?? [
            .init(name: "Universitas Ciputra", kind: .start),
            .init(name: "SPBU Pertamina Lontar", kind: .checkpoint),
            .init(name: "Ciputra World", kind: .destination)
        ]
        let resolved = participants ?? Self.defaultDummyParticipants
        self.participants = resolved
        self.isCurrentUserLeader = isCurrentUserLeader
        if let currentUserId {
            self.currentUserId = currentUserId
        } else if isCurrentUserLeader, let initialLeader = resolved.first(where: { $0.isLeader }) {
            self.currentUserId = initialLeader.id
        } else if !isCurrentUserLeader, let firstMember = resolved.first(where: { !$0.isLeader }) {
            self.currentUserId = firstMember.id
        } else {
            self.currentUserId = UUID()
        }
        self.isSelectionMode = false
        self.selectedParticipantIds = []
        self.tripStatus = .waiting
    }

    public func StartTrip() {
        guard isCurrentUserLeader else { return }
        tripStatus = .inTrip
    }

    public func ToggleSelectionMode() {
        isSelectionMode.toggle()
        if !isSelectionMode { selectedParticipantIds.removeAll() }
    }

    public func ToggleParticipantSelection(id: UUID) {
        guard let participant = participants.first(where: { $0.id == id }), !participant.isLeader else { return }
        if selectedParticipantIds.contains(id) {
            selectedParticipantIds.remove(id)
        } else {
            selectedParticipantIds.insert(id)
        }
    }

    public func SelectAll() {
        let memberIds = participants.filter { !$0.isLeader }.map(\.id)
        selectedParticipantIds = (selectedParticipantIds.count == memberIds.count) ? [] : Set(memberIds)
    }

    public func RemoveSelectedParticipants() {
        participants.removeAll(where: { selectedParticipantIds.contains($0.id) && !$0.isLeader })
        selectedParticipantIds.removeAll()
        isSelectionMode = false
    }

    public func RemoveParticipant(id: UUID) {
        guard let participant = participants.first(where: { $0.id == id }), !participant.isLeader else { return }
        participants.removeAll(where: { $0.id == id })
        selectedParticipantIds.remove(id)
    }

    public func RemoveParticipantConfirmationTitle(for participant: Participant) -> String {
        "Remove \(participant.name) from the trip?"
    }

    public func CanKick(participant: Participant) -> Bool {
        isCurrentUserLeader && !isSelectionMode && !participant.isLeader
    }

    public func CanSetLeader(participant: Participant) -> Bool {
        CanKick(participant: participant)
    }

    public func SetLeader(to participant: Participant) {
        guard participants.contains(where: { $0.id == participant.id }) else { return }
        for index in participants.indices {
            participants[index].isLeader = (participants[index].id == participant.id)
        }
        if let leader = participants.first(where: { $0.isLeader }) {
            isCurrentUserLeader = (leader.id == currentUserId)
        }
    }

    public func SetLeaderConfirmationTitle(for participant: Participant) -> String {
        "Set \(participant.name) as Trip Leader?"
    }

    public func CanEdit(participant: Participant) -> Bool {
        !isSelectionMode && (isCurrentUserLeader || participant.id == currentUserId)
    }

    public func UpdateParticipant(id: UUID, name: String, description: String) {
        guard let index = participants.firstIndex(where: { $0.id == id }) else { return }
        participants[index].name = name
        participants[index].description = description
    }

    public func LeaveRoom() {
        tripStatus = .cancelled
    }
}

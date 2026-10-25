import Foundation
import Observation

/// View model managing state and actions for the Trip Room screen.
@Observable
@MainActor
public final class TripRoomViewModel {
    /// Represents the current lifecycle status of the trip room.
    public enum TripStatus: Equatable, Sendable {
        case waiting
        case inTrip
        case cancelled
    }

    public var originName: String
    public var destinationName: String
    public var participants: [Participant]
    public var isCurrentUserLeader: Bool
    public var isSelectionMode: Bool
    public var tripStatus: TripStatus

    public init(
        originName: String = "Cilandak Town Square, Jakarta",
        destinationName: String = "Puncak Pass Resort, Bogor",
        participants: [Participant] = [],
        isCurrentUserLeader: Bool = true
    ) {
        self.originName = originName
        self.destinationName = destinationName
        self.participants = participants
        self.isCurrentUserLeader = isCurrentUserLeader
        self.isSelectionMode = false
        self.tripStatus = .waiting
    }

    /// Starts the trip if the current user is the leader.
    public func StartTrip() {
        guard isCurrentUserLeader else { return }
        tripStatus = .inTrip
    }

    /// Toggles the multi-selection mode for managing participants.
    public func ToggleSelectionMode() {
        isSelectionMode.toggle()
    }

    /// Designates a participant as the new leader and clears leadership from others.
    public func SetLeader(to participant: Participant) {
        guard participants.contains(where: { $0.id == participant.id }) else { return }
        for index in participants.indices {
            participants[index].isLeader = (participants[index].id == participant.id)
        }
    }

    /// Cancels or exits the trip room.
    public func LeaveRoom() {
        tripStatus = .cancelled
    }
}

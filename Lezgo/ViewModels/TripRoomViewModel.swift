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

    /// Represents the kind of stop along a trip route.
    public enum RouteStopKind: Equatable, Sendable {
        case start
        case checkpoint
        case destination
    }

    /// Represents a stop along the planned trip route.
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
    public var tripStatus: TripStatus

    public var inviteURL: URL {
        if let deepLink = URL(string: "lezgo://join?code=\(roomCode)") {
            return deepLink
        }
        var components = URLComponents()
        components.scheme = "https"
        components.host = "lezgo.app"
        components.path = "/join/\(roomCode)"
        return components.url ?? URL(fileURLWithPath: "/")
    }

    public var originName: String {
        routeStops.first(where: { $0.kind == .start })?.name ?? ""
    }

    public var destinationName: String {
        routeStops.last(where: { $0.kind == .destination })?.name ?? ""
    }

    public init(
        roomCode: String = "5JUV83",
        routeStops: [RouteStop]? = nil,
        originName: String = "Cilandak Town Square, Jakarta",
        destinationName: String = "Puncak Pass Resort, Bogor",
        participants: [Participant] = [],
        isCurrentUserLeader: Bool = true,
        currentUserId: UUID? = nil
    ) {
        self.roomCode = roomCode
        if let routeStops {
            self.routeStops = routeStops
        } else {
            self.routeStops = [
                .init(name: originName, kind: .start),
                .init(name: "Rest Area KM 45 Jagorawi", kind: .checkpoint),
                .init(name: destinationName, kind: .destination)
            ]
        }
        self.participants = participants
        self.isCurrentUserLeader = isCurrentUserLeader
        if let currentUserId {
            self.currentUserId = currentUserId
        } else if isCurrentUserLeader, let initialLeader = participants.first(where: { $0.isLeader }) {
            self.currentUserId = initialLeader.id
        } else if !isCurrentUserLeader, let firstMember = participants.first(where: { !$0.isLeader }) {
            self.currentUserId = firstMember.id
        } else {
            self.currentUserId = UUID()
        }
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
        if let leader = participants.first(where: { $0.isLeader }) {
            isCurrentUserLeader = (leader.id == currentUserId)
        }
    }

    /// Cancels or exits the trip room.
    public func LeaveRoom() {
        tripStatus = .cancelled
    }
}

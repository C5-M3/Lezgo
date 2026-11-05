//
//  TripMapNotices.swift
//  Lezgo
//
//  Created by Nathan Sudiara on 05/11/26.
//

import Foundation

/// The notices as one phone sees them: what changed since the last trip state, and which notice to show
/// (`specs/UserStories.md` → US-06, "Route changes" and "Leader offline").
struct TripMapNotices {
    /// How long the leader must be gone before the only member left takes over.
    static let takeOverAfter: TimeInterval = 300

    /// `true` once this phone tried to take over as the only member left, so it asks only once.
    var hasTriedTakeOver = false

    private var seen: Seen?
    private var recent: Recent?
    /// The "offline" banner was closed. It stays hidden until the leader has been back.
    private var isOfflineBannerClosed = false

    private struct Stop: Hashable {
        let name: String
        let coordinate: Coordinate
    }

    private struct Seen {
        let routeVersion: Int
        let stops: [Stop]
        let leaderID: UUID
        let leaderLastSeenAt: Date?
    }

    /// What has just happened. Only the latest is kept, so several reroutes in a row show one notice.
    private enum Recent {
        case route(stopsChanged: Bool)
        case newLeader(id: UUID)
    }

    /// Notes what changed since the last state.
    mutating func Update(_ state: TripState) {
        let now = Seen(
            routeVersion: state.trip.routeVersion,
            stops: Stops(of: state),
            leaderID: state.trip.leaderParticipantID,
            leaderLastSeenAt: state.leader?.lastSeenAt
        )
        defer { seen = now }
        guard let seen else { return }
        if now.routeVersion > seen.routeVersion, state.trip.status == .inTrip {
            recent = .route(stopsChanged: now.stops != seen.stops)
        }
        if now.leaderID != seen.leaderID {
            recent = .newLeader(id: now.leaderID)
            isOfflineBannerClosed = false
        }
        if let before = seen.leaderLastSeenAt, let after = now.leaderLastSeenAt, after > before {
            isOfflineBannerClosed = false
        }
    }

    /// The one notice to show: a failed reroute, then an offline leader, then what has just happened.
    func Notice(in state: TripState, me: UUID, rerouteFailed: Bool, at date: Date) -> TripMapNotice? {
        let isLeader = state.trip.leaderParticipantID == me
        if rerouteFailed, isLeader { return .rerouteFailed }
        if let leader = state.leader, isLeader == false, leader.IsOnline(at: date) == false, !isOfflineBannerClosed {
            return .leaderOffline(name: state.DisplayName(of: leader))
        }
        let leaderName = state.leader.flatMap { isLeader ? nil : state.DisplayName(of: $0) }
        switch recent {
        case .route(stopsChanged: true): return .routeUpdated(leaderName: leaderName)
        case .route(stopsChanged: false): return .newRoute(leaderName: leaderName)
        case let .newLeader(id):
            return state.participants.first { $0.id == id }.map { .newLeader(name: state.DisplayName(of: $0)) }
        case nil: return nil
        }
    }

    /// A tap on the banner, or the end of its time on screen. A failed reroute stays until a new route is found.
    mutating func Close(_ notice: TripMapNotice) {
        switch notice {
        case .newRoute, .routeUpdated, .newLeader: recent = nil
        case .leaderOffline: isOfflineBannerClosed = true
        case .rerouteFailed: break
        }
    }

    /// With the leader gone for 5 minutes and this phone the only member left, there is nobody else to choose.
    static func ShouldTakeOver(_ state: TripState, me: UUID, at date: Date) -> Bool {
        guard let leader = state.leader, leader.id != me, state.participants.count == 2 else { return false }
        return date.timeIntervalSince(leader.lastSeenAt) >= takeOverAfter
    }

    /// The stops still ahead; the start point changes with every reroute, so it does not count.
    private func Stops(of state: TripState) -> [Stop] {
        let index = state.trip.currentWaypointIndex
        return state.waypoints
            .filter { $0.kind != .start && $0.IsVisited(currentWaypointIndex: index) == false }
            .sorted { $0.orderIndex < $1.orderIndex }
            .map { Stop(name: $0.name, coordinate: $0.coordinate) }
    }
}

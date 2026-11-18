//
//  TripRecapShareCardContent.swift
//  Lezgo
//

import Foundation

/// The words and the leader's robot on the trip recap picture that is shared (From, To, Time, Distance).
/// It reads the same resolved values as the detail screen, so the picture never disagrees with the screen.
struct TripRecapShareCardContent: Equatable {
    let dateText: String
    let fromText: String
    /// The destination, with "+N Dest." after it when the trip had stops.
    let toText: String
    let timeText: String
    let distanceText: String
    let leaderAvatar: Avatar

    init(recap: TripRecap) {
        dateText = recap.formattedDate
        fromText = recap.resolvedStartPointName
        toText = recap.resolvedStopsCount > 0
            ? "\(recap.destinationName) +\(recap.resolvedStopsCount) Dest."
            : recap.destinationName
        timeText = recap.resolvedDurationText
        distanceText = recap.distanceText
        leaderAvatar = recap.resolvedParticipants.first(where: \.isLeader)?.avatar ?? recap.avatars.first ?? .yellow
    }
}

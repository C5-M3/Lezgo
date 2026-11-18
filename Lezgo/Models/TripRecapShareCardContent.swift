//
//  TripRecapShareCardContent.swift
//  Lezgo
//

import Foundation

/// The words and the leader's robot on the trip recap picture that is shared (From, To, Time, Distance).
struct TripRecapShareCardContent: Equatable {
    var dateText = ""
    var fromText = ""
    var toText = ""
    var timeText = ""
    var distanceText = ""
    var leaderAvatar: Avatar = .yellow

    init(recap: TripRecap) {}
}

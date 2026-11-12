//
//  TripActivityAttributes.swift
//  Lezgo
//
//  Created by Nathan Sudiara on 12/11/26.
//

import ActivityKit
import Foundation

/// The trip's Live Activity on the Lock Screen, in the Dynamic Island and on the CarPlay dashboard (ADR 0027).
///
/// Shared by the app, which fills it from the open trip map, and the `LezgoWidgets` extension, which draws it. Every
/// text is localized by the app before it is sent, so the extension needs no strings of its own.
nonisolated struct TripActivityAttributes: ActivityAttributes {
    /// "To Puncak"
    var title: String

    /// What the activity shows now. ActivityKit allows at most 4 KB, so it holds short texts and a few numbers.
    struct ContentState: Codable, Hashable {
        var stage: Stage
        var turn: Turn?
        /// The small line at the top: "Next stop · Rest area KM 57", "To Puncak" on the last leg, the destination's
        /// name once arrived.
        var headline: String
        /// "Rerouting…" while the route is being found again.
        var statusText: String?
        /// "1 hr, 20 min"
        var timeLeftText: String?
        /// "33 min" or "1:20", for the compact Dynamic Island.
        var shortTimeLeftText: String?
        /// "11:01", the clock time of arrival.
        var arrivalTimeText: String?
        /// "64 km · Arrive 11:01"
        var detailText: String?
        /// "Following Budi" for a member, "3/4 cars on route" for the leader.
        var groupText: String
        /// The leader's group line turns red while a car is off the route.
        var isGroupWarning: Bool
        var alert: Alert?
        /// "You have arrived" and "3/4", once this car has arrived.
        var arrival: Arrival?
        /// The cars as robots on the convoy road, at most `maxRobots`; cars close together share one robot.
        var robots: [Robot]
        /// The checkpoints as numbered posts on the convoy road.
        var stops: [Stop]
        /// This phone's own robot, for the mascot sticker and the Dynamic Island.
        var myColor: RobotColor
        var isLeader: Bool
        var isMuted: Bool
        /// "Mute" or "Unmute"
        var muteLabel: String
    }

    enum Stage: String, Codable, Hashable {
        /// Waiting for the first guidance.
        case loading
        case driving
        /// "Rerouting…"
        case rerouting
        case arrived
    }

    struct Turn: Codable, Hashable {
        /// The SF Symbol of the arrow, the same one the turn card and CarPlay use.
        var symbolName: String
        /// "300 m"
        var distanceText: String
        /// "Turn right onto Jl. Raya Puncak"
        var instruction: String
    }

    struct Alert: Codable, Hashable {
        /// The same text as the map's banner: "Citra has gone out of route".
        var text: String
        /// "Off route", "Stopped": what fits beside the camera in the compact Dynamic Island.
        var shortText: String
        /// "400 m behind you", for another car's alert; `nil` for this phone's own.
        var detail: String?
        /// The car the alert is about, so its robot can stand in for this phone's robot.
        var color: RobotColor
        /// "Citra", or "You".
        var carName: String
    }

    struct Arrival: Codable, Hashable {
        var title: String
        /// "3/4"
        var countText: String
        /// "Waiting for everyone to arrive"
        var detail: String?
    }

    /// A car on the convoy road, standing for `groupCount` cars that are close together.
    struct Robot: Codable, Hashable, Identifiable {
        let id: UUID
        var color: RobotColor
        /// How far along the route the car is: 0 at the start, 1 at the destination.
        var progress: Double
        var isMe: Bool
        var isLeader: Bool
        var isAlerting: Bool
        var groupCount = 1
    }

    /// A checkpoint on the convoy road.
    struct Stop: Codable, Hashable, Identifiable {
        /// 1 for the first checkpoint.
        var number: Int
        var progress: Double
        /// The group has passed it.
        var isVisited: Bool

        var id: Int { number }
    }

    /// The robot images, one per avatar colour.
    enum RobotColor: String, Codable, Hashable, CaseIterable {
        case yellow, purple, pink, blue, green
    }

    /// More robots would not fit on the road of the smallest Lock Screen.
    static let maxRobots = 8
    /// Cars nearer than this share one robot, so they do not pile up into a blob.
    static let groupDistance = 0.05
}

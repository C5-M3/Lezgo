//
//  TripActivityAttributes.swift
//  Lezgo
//
//  Created by Nathan Sudiara on 12/11/26.
//

import ActivityKit
import Foundation

/// The trip's Live Activity on the Lock Screen, in the Dynamic Island, on the CarPlay dashboard, on Apple Watch and
/// on a Mac (ADR 0027).
///
/// It shows only the current leg: from the last stop (or the start) to the next stop, with every car on the way.
/// Alerts and turns stay in the app. Shared by the app, which fills it from the open trip map, and the
/// `LezgoWidgets` extension, which draws it. Every text is localized by the app before it is sent.
nonisolated struct TripActivityAttributes: ActivityAttributes {
    /// "To Pakuwon mall", the whole trip's destination.
    var title: String

    /// What the activity shows now. ActivityKit allows at most 4 KB, so it holds short texts and a few numbers.
    struct ContentState: Codable, Hashable {
        var stage: Stage
        /// "To Rest Area KM 57", or "You have arrived".
        var title: String
        /// "50 min" or "1 hr, 20 min" to the next stop; `nil` until it is known and once arrived.
        var timeText: String?
        /// "50 min" or "1:20", for the compact Dynamic Island.
        var shortTimeText: String?
        /// "12 km" to the next stop; `nil` until it is known and once arrived.
        var distanceText: String?
        /// "3/4" once arrived.
        var countText: String?
        /// Under the start of the road: "Start", the stop just passed, or "Waiting for everyone to arrive".
        var legStartLabel: String
        /// Under the flag: "Stop 1 of 2" or "Destination".
        var legEndLabel: String
        /// Every car on the leg, at most `maxRobots`.
        var robots: [Robot]
        /// How far the yellow line goes: to the car furthest ahead, 0 to 1.
        var reached: Double
        /// This phone's own robot, for the Dynamic Island.
        var myColor: RobotColor
    }

    enum Stage: String, Codable, Hashable {
        /// Waiting for the first guidance.
        case loading
        case driving
        case arrived
    }

    /// A car on the road.
    struct Robot: Codable, Hashable, Identifiable {
        let id: UUID
        var color: RobotColor
        /// How far along the current leg the car is: 0 at its start, 1 at the next stop.
        var progress: Double
        var isMe: Bool
        /// Offline cars show their robot with the screen off.
        var isOnline: Bool
    }

    /// The robot images, one per avatar colour.
    enum RobotColor: String, Codable, Hashable, CaseIterable {
        case yellow, purple, pink, blue, green
    }

    /// More robots would not fit on the road of the smallest Lock Screen.
    static let maxRobots = 8
}

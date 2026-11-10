//
//  TripMapCarPin.swift
//  Lezgo
//
//  Created by Nathan Sudiara on 26/10/26.
//

import Foundation

/// A car pin as the trip map draws it: the car plus the facts the pin's look depends on.
struct TripMapCarPin: Identifiable, Hashable {
    let id: UUID
    var displayName: String
    var coordinate: Coordinate
    var motionState: MotionState
    /// The way the car is heading, in degrees clockwise from north; `nil` draws the car without a direction.
    var course: Double?
    var isLeader: Bool
    var isMe: Bool
    /// Offline cars stay at their last position and are drawn faded.
    var isOffline: Bool
    /// Another car that is off the route or ahead of the leader; its pin is highlighted.
    var isAlerting = false
    /// Which robot this car drives.
    var carColor = CarColor.yellow

    /// The name under the robot: "You" under this phone's own car, so the driver finds themselves at a glance.
    var label: String {
        isMe ? String(localized: .tripMapCarYou) : displayName
    }

    /// The small round badge on the robot's shoulder; `nil` for a car driving with nothing to report.
    var badge: Badge? {
        if isAlerting { return .alert }
        return motionState == .stopped ? .stopped : nil
    }

    /// What VoiceOver says about the car after its name, such as "You, Leader, Stopped".
    var statuses: [String] {
        var statuses: [String] = []
        if isMe { statuses.append(String(localized: .tripMapCarYou)) }
        if isLeader { statuses.append(String(localized: .tripMapCarLeader)) }
        if isAlerting { statuses.append(String(localized: .tripMapCarAlert)) }
        if isOffline {
            statuses.append(String(localized: .tripMapCarOffline))
        } else {
            statuses.append(String(localized: motionState == .stopped ? .tripMapCarStopped : .tripMapCarDriving))
        }
        return statuses
    }

    /// A badge on the robot: a red warning for a car off the route or ahead of the leader, a pause for a stopped car.
    enum Badge {
        case alert, stopped

        /// The SF Symbol drawn on the badge.
        var symbolName: String {
            switch self {
            case .alert: "exclamationmark"
            case .stopped: "pause.fill"
            }
        }
    }

    /// The robot colors in the asset catalog: yellow for the leader, the others for the members.
    enum CarColor: Hashable {
        case yellow, purple, pink, blue, green

        /// The color of the member at `index` among the members, in join order. Colors repeat after the fourth.
        static func ForMember(atIndex index: Int) -> CarColor {
            let memberColors: [CarColor] = [.purple, .pink, .blue, .green]
            return memberColors[index % memberColors.count]
        }
    }
}

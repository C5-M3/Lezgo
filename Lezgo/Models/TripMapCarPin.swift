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

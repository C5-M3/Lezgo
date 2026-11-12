//
//  TripActivityRobotHead.swift
//  LezgoWidgets
//
//  Created by Nathan Sudiara on 12/11/26.
//

import SwiftUI

/// A car's robot seen from the front, with its face lit, or with the screen off while the car is offline.
struct TripActivityRobotHead: View {
    let color: TripActivityAttributes.RobotColor
    var isOnline = true
    let size: CGFloat

    var body: some View {
        Image(isOnline ? color.head : color.headOff)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

extension TripActivityAttributes.RobotColor {
    /// The robot with its face lit.
    var head: ImageResource {
        switch self {
        case .yellow: .robotHeadYellow
        case .purple: .robotHeadPurple
        case .pink: .robotHeadPink
        case .blue: .robotHeadBlue
        case .green: .robotHeadGreen
        }
    }

    /// The robot with its screen off.
    var headOff: ImageResource {
        switch self {
        case .yellow: .robotHeadOffYellow
        case .purple: .robotHeadOffPurple
        case .pink: .robotHeadOffPink
        case .blue: .robotHeadOffBlue
        case .green: .robotHeadOffGreen
        }
    }
}

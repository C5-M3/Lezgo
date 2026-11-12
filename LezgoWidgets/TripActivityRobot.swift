//
//  TripActivityRobot.swift
//  LezgoWidgets
//
//  Created by Nathan Sudiara on 12/11/26.
//

import SwiftUI

/// The pictures of each robot colour in the extension's own asset catalog, small enough for a Live Activity.
extension TripActivityAttributes.RobotColor {
    /// The robot seen from above, as it drives on the map.
    var robot: ImageResource {
        switch self {
        case .yellow: .robotYellow
        case .purple: .robotPurple
        case .pink: .robotPink
        case .blue: .robotBlue
        case .green: .robotGreen
        }
    }

    /// This phone's own robot: the same, with a glow.
    var glowingRobot: ImageResource {
        switch self {
        case .yellow: .robotGlowYellow
        case .purple: .robotGlowPurple
        case .pink: .robotGlowPink
        case .blue: .robotGlowBlue
        case .green: .robotGlowGreen
        }
    }

    /// The mascot sticker, waving.
    var sticker: ImageResource {
        switch self {
        case .yellow: .stickerYellow
        case .purple: .stickerPurple
        case .pink: .stickerPink
        case .blue: .stickerBlue
        case .green: .stickerGreen
        }
    }
}

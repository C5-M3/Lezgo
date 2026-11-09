//
//  TripMapCarColor+Images.swift
//  Lezgo
//
//  Created by Nathan Sudiara on 05/11/26.
//

import SwiftUI

extension TripMapCarPin.CarColor {
    /// The robot seen from above, as a car on the map. The tapped car glows.
    func TopViewImage(isGlowing: Bool) -> ImageResource {
        switch (self, isGlowing) {
        case (.yellow, false): .ontripNoglowYellow
        case (.yellow, true): .ontripGlowYellow
        case (.purple, false): .ontripNoglowPurple
        case (.purple, true): .ontripGlowPurple
        case (.pink, false): .ontripNoglowPink
        case (.pink, true): .ontripGlowPink
        case (.blue, false): .ontripNoglowBlue
        case (.blue, true): .ontripGlowBlue
        case (.green, false): .ontripNoglowGreen
        case (.green, true): .ontripGlowGreen
        }
    }

    /// The robot seen from the front, as on the arrival card and the car status card.
    var frontImage: ImageResource {
        switch self {
        case .yellow: .frontballActiveYellow
        case .purple: .frontballActivePurple
        case .pink: .frontballActivePink
        case .blue: .frontballActiveBlue
        case .green: .frontballActiveGreen
        }
    }
}

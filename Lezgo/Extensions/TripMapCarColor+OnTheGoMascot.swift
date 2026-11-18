//
//  TripMapCarColor+OnTheGoMascot.swift
//  Lezgo
//
//  Created by Oky Faishal on 18/11/26.
//

import SwiftUI

extension TripMapCarPin.CarColor {
    /// The mascot with its arms up, as the hi-fi shows it on the On the Go list. All five share one canvas, so the
    /// head sits in the same place whatever the colour.
    var onTheGoMascotImage: ImageResource {
        switch self {
        case .yellow: .onTheGoMascotYellow
        case .purple: .onTheGoMascotPurple
        case .green: .onTheGoMascotGreen
        case .pink: .onTheGoMascotPink
        case .blue: .onTheGoMascotBlue
        }
    }
}

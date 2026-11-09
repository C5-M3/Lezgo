//
//  TripMapCarColor+Color.swift
//  Lezgo
//
//  Created by Nathan Sudiara on 09/11/26.
//

import SwiftUI

extension TripMapCarPin.CarColor {
    /// The robot's colour, for lines drawn for that car, such as its way back to the group's road.
    var color: Color {
        switch self {
        case .yellow: Color(.brandYellow)
        case .purple: Color(.brandPurple)
        case .pink: Color(.brandPink)
        case .blue: Color(.brandBlue)
        case .green: Color(.brandGreen)
        }
    }
}

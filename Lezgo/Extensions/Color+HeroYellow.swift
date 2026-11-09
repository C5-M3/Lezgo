//
//  Color+HeroYellow.swift
//  Lezgo
//
//  Created by Farrell Sudjatmiko on 05/11/26.
//

import SwiftUI
import UIKit

extension Color {
    /// Hero yellow brand color (`#F7FF00`) used for primary route accents, buttons, and highlights.
    static let heroYellow = Color(
        red: 247.0 / 255.0,
        green: 1.0,
        blue: 0.0
    )
}

extension UIColor {
    /// Hero yellow brand color (`#F7FF00`) used for MapKit overlays and UIKit components.
    static let heroYellow = UIColor(
        red: 247.0 / 255.0,
        green: 1.0,
        blue: 0.0,
        alpha: 1.0
    )
}

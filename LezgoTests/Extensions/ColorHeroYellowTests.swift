//
//  ColorHeroYellowTests.swift
//  LezgoTests
//
//  Created by Farrell Sudjatmiko on 05/11/26.
//

import SwiftUI
import Testing
import UIKit
@testable import Lezgo

struct ColorHeroYellowTests {
    @Test func HeroYellowMatchesHexF7FF00() {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0

        UIColor.heroYellow.getRed(&red, green: &green, blue: &blue, alpha: &alpha)

        #expect(abs(red - (247.0 / 255.0)) < 0.001)
        #expect(abs(green - 1.0) < 0.001)
        #expect(abs(blue - 0.0) < 0.001)
        #expect(abs(alpha - 1.0) < 0.001)
    }
}

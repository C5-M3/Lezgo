//
//  AnimationMotionTests.swift
//  LezgoTests
//
//  Created by Nathan Sudiara on 09/11/26.
//

import SwiftUI
import Testing
@testable import Lezgo

struct AnimationMotionTests {
    @Test(arguments: [Animation.lezgoSwap, .lezgoPanel, .lezgoDialog, .lezgoPress])
    func MotionIsDroppedWithReduceMotion(animation: Animation) {
        #expect(animation.Respecting(reduceMotion: true) == nil)
    }

    @Test(arguments: [Animation.lezgoSwap, .lezgoPanel, .lezgoDialog, .lezgoPress])
    func MotionIsKeptWithoutReduceMotion(animation: Animation) {
        #expect(animation.Respecting(reduceMotion: false) == animation)
    }
}

//
//  HomeViewModel+Split.swift
//  Lezgo
//
//  Created by Nathan Sudiara on 16/11/26.
//

import Foundation

/// The runs the split-screen Home plays for LEAD, JOIN and Back (issue #329). The view runs each step as one
/// animation, calling `BeginSplitStep` before it and `FinishSplitStep` after it, then `FinishSplitMotion`.
extension HomeViewModel {
    private typealias Motion = HomeSplitMotion
    private typealias Step = HomeSplitMotion.Step

    /// What a tap on a half does. The team tries both on phones; the build picks one.
    enum TapStyle: Equatable {
        /// A tap on either half goes to its next screen, swinging the split first if that half is dark.
        case oneTap
        /// A tap on the dark half only swings it to yellow; a tap on the yellow half goes to its next screen.
        case twoTap

        /// Two taps when the app is built with the `LEZGO_HOME_TWO_TAP` compilation condition, one tap otherwise.
        static var build: TapStyle {
            #if LEZGO_HOME_TWO_TAP
            .twoTap
            #else
            .oneTap
            #endif
        }
    }

    /// `true` on the JOIN home, where JOIN is the yellow half.
    var isOnJoinHome: Bool {
        isOnAHome && splitProgress > 0
    }

    /// LEAD: Set Route. From the JOIN home the split swings back first, and with two taps it stops there.
    func LeadTapped() -> [HomeSplitMotion.Step] {
        guard isOnAHome else { return [] }
        guard isOnJoinHome else { return [Step(flow: .lead, target: 1)] }
        let swingBack = Step(flow: .swingBack, target: 0)
        return tapStyle == .twoTap ? [swingBack] : [swingBack, Step(flow: .lead, target: 1)]
    }

    /// JOIN: Enter room code. From the LEAD home the split swings first, and with two taps it stops on the JOIN home.
    func JoinTapped() -> [HomeSplitMotion.Step] {
        guard isOnAHome else { return [] }
        let target = tapStyle == .twoTap && !isOnJoinHome ? Motion.joinHome : 1
        return [Step(flow: .join, target: target)]
    }

    /// Back from Set Route returns to the LEAD home; Back from Enter room code stops on the JOIN home.
    func BackTapped() -> [HomeSplitMotion.Step] {
        guard !isSplitMoving, let destination = splitDestination else { return [] }
        return [Step(flow: destination, target: destination == .join ? Motion.joinHome : 0)]
    }

    func BeginSplitStep(_ step: HomeSplitMotion.Step) {
        isSplitMoving = true
        splitStepStart = splitProgress
        splitFlow = step.flow
        splitProgress = step.target
        // The next screen is on for the whole run that brings it in; its wipe keeps it hidden until its turn.
        if step.target == 1 {
            splitDestination = step.flow
        }
    }

    func FinishSplitStep(_ step: HomeSplitMotion.Step) {
        // It stays on while it wipes away, and goes once it is fully off screen.
        if step.target < 1 {
            splitDestination = nil
        }
    }

    func FinishSplitMotion() {
        isSplitMoving = false
    }

    /// An invite link or a plan link opens its screen at once, without the motion.
    func ShowSplitDestination(_ flow: HomeSplitMotion.Flow) {
        splitFlow = flow
        splitProgress = 1
        splitStepStart = 1
        splitDestination = flow
        isSplitMoving = false
    }

    /// Back to the LEAD home at once, when a trip takes over from Set Route or Enter room code.
    func ResetSplit() {
        splitFlow = .lead
        splitProgress = 0
        splitStepStart = 0
        splitDestination = nil
        isSplitMoving = false
    }

    private var isOnAHome: Bool {
        !isSplitMoving && splitDestination == nil
    }
}

//
//  HomeViewModel+Split.swift
//  Lezgo
//
//  Created by Nathan Sudiara on 16/11/26.
//

import Foundation

/// The steps the split-screen Home plays for LEAD, JOIN and Back (issue #329). The view runs each step as one
/// animation, calling `BeginSplitStep` before it and `FinishSplitStep` after it, then `FinishSplitMotion`.
extension HomeViewModel {
    private typealias Motion = HomeSplitMotion
    private typealias Step = HomeSplitMotion.Step

    /// LEAD: Set Route. From the JOIN home the split flips back first.
    func LeadTapped() -> [HomeSplitMotion.Step] {
        guard isOnAHome else { return [] }
        let flipBack = splitFlow == .join && splitProgress > 0 ? [Step(flow: .join, target: 0)] : []
        return flipBack + ForwardSteps(.lead, from: splitFlow == .lead ? splitProgress : 0)
    }

    /// JOIN: Enter room code, from the LEAD home or the JOIN home.
    func JoinTapped() -> [HomeSplitMotion.Step] {
        guard isOnAHome else { return [] }
        return ForwardSteps(.join, from: splitFlow == .join ? splitProgress : 0)
    }

    /// Back from Set Route returns to the LEAD home; Back from Enter room code stops on the JOIN home.
    func BackTapped() -> [HomeSplitMotion.Step] {
        guard !isSplitMoving, let destination = splitDestination else { return [] }
        let home = destination == .join ? Motion.joinHome : 0
        return [
            Step(flow: destination, target: Motion.RevealStart(of: destination)),
            Step(flow: destination, target: home)
        ]
    }

    func BeginSplitStep(_ step: HomeSplitMotion.Step) {
        isSplitMoving = true
        splitFlow = step.flow
        splitProgress = step.target
        // The next screen is on from the moment its wipe starts.
        if step.target > Motion.RevealStart(of: step.flow) {
            splitDestination = step.flow
        }
    }

    func FinishSplitStep(_ step: HomeSplitMotion.Step) {
        // It stays on while it wipes away, and goes once it is fully off screen.
        if step.target <= Motion.RevealStart(of: step.flow) {
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
        splitDestination = flow
        isSplitMoving = false
    }

    /// Back to the LEAD home at once, when a trip takes over from Set Route or Enter room code.
    func ResetSplit() {
        splitFlow = .lead
        splitProgress = 0
        splitDestination = nil
        isSplitMoving = false
    }

    private var isOnAHome: Bool {
        !isSplitMoving && splitDestination == nil
    }

    private func ForwardSteps(_ flow: HomeSplitMotion.Flow, from start: Double) -> [HomeSplitMotion.Step] {
        let revealStart = Motion.RevealStart(of: flow)
        let fill = start < revealStart ? [Step(flow: flow, target: revealStart)] : []
        return fill + [Step(flow: flow, target: 1)]
    }
}

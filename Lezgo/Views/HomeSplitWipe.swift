//
//  HomeSplitWipe.swift
//  Lezgo
//
//  Created by Nathan Sudiara on 16/11/26.
//

import SwiftUI

/// Wipes Set Route or Enter room code over the split-screen Home (issue #329): it shows only the part of the screen
/// the next screen covers at `progress`, and slides it the last few points into place.
struct HomeSplitWipe: ViewModifier, Animatable {
    let flow: HomeSplitMotion.Flow
    var progress: Double
    /// The screen height the 874-point design is scaled to.
    let canvasHeight: Double

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func body(content: Content) -> some View {
        let frame = HomeSplitMotion.FrameAt(flow, progress: progress)
        let slide = flow == .lead ? frame.leadDestinationOffset : frame.joinDestinationOffset
        content
            .offset(y: slide * canvasHeight / HomeSplitMotion.canvasHeight)
            .mask {
                HomeSplitShape(
                    part: flow == .lead ? .leadDestination : .joinDestination,
                    flow: flow,
                    progress: progress
                )
                    // The next screen keeps the safe area for its own layout, but the wipe crosses the whole screen.
                    .ignoresSafeArea()
            }
    }
}

extension AnyTransition {
    /// The next screen comes in with the wipe from where it starts, `HomeSplitMotion.RevealStart`, and is fully
    /// shown at the end. With Reduce Motion it fades instead.
    static func homeSplitWipe(_ flow: HomeSplitMotion.Flow, canvasHeight: Double, reduceMotion: Bool) -> AnyTransition {
        guard !reduceMotion else { return .opacity }
        return .modifier(
            active: HomeSplitWipe(
                flow: flow,
                progress: HomeSplitMotion.RevealStart(of: flow),
                canvasHeight: canvasHeight
            ),
            identity: HomeSplitWipe(flow: flow, progress: 1, canvasHeight: canvasHeight)
        )
    }
}

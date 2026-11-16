//
//  HomeSplitPlacement.swift
//  Lezgo
//
//  Created by Nathan Sudiara on 16/11/26.
//

import SwiftUI

/// Moves one element of the split-screen Home (issue #329) to where `HomeSplitMotion` puts it at `progress`. The
/// element is laid out at the top left of a screen-sized stack; this offsets, scales and fades it.
struct HomeSplitPlacement: ViewModifier, Animatable {
    enum Element {
        case leadWord
        case joinWord
        case mascot
        /// A crew mascot, by its index in `HomeSplitMotion.crewSlots`.
        case crew(Int)
    }

    let element: Element
    let flow: HomeSplitMotion.Flow
    var progress: Double
    /// The screen size the 402 × 874 design is scaled to.
    let canvas: CGSize

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func body(content: Content) -> some View {
        let frame = HomeSplitMotion.FrameAt(flow, progress: progress)
        let fit = HomeSplitMotion.FitOn(width: canvas.width, height: canvas.height)

        switch element {
        case .leadWord:
            Word(content, frame.leadWord, fit: fit)
        case .joinWord:
            Word(content, frame.joinWord, fit: fit)
        case .mascot:
            let slot = HomeSplitMotion.mascotSlot
            // The squash and tilt pivot near its feet, so it pushes off the ground.
            let pivot = UnitPoint(x: 150 / slot.width, y: 300 / slot.height)
            content
                .scaleEffect(x: frame.mascot.scaleX, y: frame.mascot.scaleY, anchor: pivot)
                .rotationEffect(.degrees(frame.mascot.rotation), anchor: pivot)
                .offset(x: fit.rightPinnedLeft + slot.x * fit.scale, y: (slot.y + frame.mascot.offset) * fit.scale)
        case .crew(let index):
            let slot = HomeSplitMotion.crewSlots[index]
            let pose = frame.crew[index]
            content
                .scaleEffect(pose.scale, anchor: .topLeading)
                .offset(x: fit.rightPinnedLeft + slot.x * fit.scale, y: (slot.y + pose.offset) * fit.scale)
        }
    }

    private func Word(
        _ content: Content,
        _ placement: HomeSplitMotion.Placement,
        fit: HomeSplitMotion.Fit
    ) -> some View {
        content
            .scaleEffect(placement.scale, anchor: .topLeading)
            .offset(x: fit.left + placement.x * fit.scale, y: placement.y * fit.scale)
            .opacity(placement.opacity)
    }
}

//
//  HomeSplitMotion.swift
//  Lezgo
//
//  Created by Nathan Sudiara on 16/11/26.
//

import Foundation

/// The split-screen Home (issue #329) as a pure function of progress: a yellow LEAD half on top, a dark JOIN half
/// below, and the motion from each half into Set Route or Enter room code. Progress runs from 0 (the LEAD home) to
/// 1 (the next screen covers Home); Back plays the same frames backwards. Positions are in points on the 402 × 874
/// design frame ("Wild 1 · Split screen" on the Sketch page "Home Options"); the view scales them to the screen.
enum HomeSplitMotion {
    /// Which half was tapped, and so which screen comes in.
    enum Flow: Equatable {
        /// LEAD: Set Route wipes in from the top.
        case lead
        /// JOIN: Enter room code wipes up from the bottom.
        case join
    }

    /// One run of the motion towards `target`; a tap can need a few in a row.
    struct Step: Equatable {
        let flow: Flow
        let target: Double
    }

    /// A diagonal line across the screen: its height at the left and at the right edge.
    struct Edge: Equatable {
        let left: Double
        let right: Double
    }

    /// Where a word sits: its top-left corner, its size against the design and how visible it is.
    struct Placement: Equatable {
        let x: Double
        let y: Double
        let scale: Double
        let opacity: Double
    }

    /// The lead mascot: how far it moved up or down, its squash and its tilt.
    struct MascotPose: Equatable {
        let offset: Double
        let scaleX: Double
        let scaleY: Double
        let rotation: Double
    }

    /// One crew mascot on the JOIN half: how far below its place it is, and its size.
    struct CrewPose: Equatable {
        let offset: Double
        let scale: Double
    }

    /// A rectangle on the design frame.
    struct Slot: Equatable {
        let x: Double
        let y: Double
        let width: Double
        let height: Double
    }

    /// How the design sits on a screen: one scale both ways, so it is never stretched, and centred across the width,
    /// as on a phone held sideways.
    struct Fit: Equatable {
        let scale: Double
        /// How far the design's left edge is from the screen's.
        let left: Double
    }

    /// Everything on screen at one moment.
    struct Frame: Equatable {
        /// The lower edge of the yellow LEAD half.
        var topSlab: Edge
        /// The upper edge of the yellow JOIN half.
        var bottomSlab: Edge
        var leadWord: Placement
        var joinWord: Placement
        var mascot: MascotPose
        /// In the order of `crewSlots`.
        var crew: [CrewPose]
        /// The lower edge of Set Route, which covers everything above it.
        var leadDestination: Edge
        /// The upper edge of Enter room code, which covers everything below it.
        var joinDestination: Edge
        /// How far Set Route still has to slide down into place.
        var leadDestinationOffset: Double
        /// How far Enter room code still has to slide up into place.
        var joinDestinationOffset: Double
    }

    static let canvasWidth = 402.0
    static let canvasHeight = 874.0
    /// Where Back from Enter room code stops: JOIN big and yellow, LEAD small on the dark half.
    static let joinHome = 0.43

    static let leadWordSize = (width: 297.0, height: 152.0)
    static let joinWordSize = (width: 139.0, height: 76.0)
    static let mascotSlot = Slot(x: 102, y: 263, width: 308, height: 333.5)
    /// Green, pink, blue, purple and yellow, from the back of the pile to the front.
    static let crewSlots = [
        Slot(x: 211.3, y: 563.7, width: 109, height: 95),
        Slot(x: 294.4, y: 630.9, width: 107.7, height: 126),
        Slot(x: 159.1, y: 659.8, width: 145, height: 136.7),
        Slot(x: 86.7, y: 746.2, width: 183.3, height: 128),
        Slot(x: 183.6, y: 698, width: 220.3, height: 172)
    ]
    static let crewCount = crewSlots.count

    /// The next screen's edge leans like the split: its left end is this much lower than its right end.
    private static let destinationTilt = 90.0
    /// The front of the pile pops up first.
    private static let crewPopOrder = [4, 3, 2, 1, 0]

    static func FitOn(width: Double, height: Double) -> Fit {
        let scale = min(width / canvasWidth, height / canvasHeight)
        return Fit(scale: scale, left: (width - canvasWidth * scale) / 2)
    }

    /// How long the whole motion takes, in seconds.
    static func TotalDuration(of flow: Flow) -> Double {
        flow == .lead ? 1.25 : 1.65
    }

    /// How long a run from `start` to `target` takes, in seconds.
    static func Duration(of flow: Flow, from start: Double, to target: Double) -> Double {
        abs(target - start) * TotalDuration(of: flow)
    }

    /// The progress at which the next screen starts to wipe in. Until then it is not on screen.
    static func RevealStart(of flow: Flow) -> Double {
        flow == .lead ? 0.38 : 0.64
    }

    static func FrameAt(_ flow: Flow, progress: Double) -> Frame {
        let time = Clamp(progress)
        return flow == .lead ? LeadFrame(at: time) : JoinFrame(at: time)
    }

    // MARK: - Frames

    private static let restFrame = Frame(
        topSlab: Edge(left: 550, right: 480),
        bottomSlab: Edge(left: 928, right: 880),
        leadWord: Placement(x: 24, y: 144, scale: 1, opacity: 1),
        joinWord: Placement(x: 24, y: 588, scale: 1, opacity: 1),
        mascot: MascotPose(offset: 0, scaleX: 1, scaleY: 1, rotation: 0),
        crew: Array(repeating: CrewPose(offset: 140, scale: 0.75), count: crewSlots.count),
        leadDestination: Edge(left: 0, right: -destinationTilt),
        joinDestination: Edge(left: canvasHeight + destinationTilt, right: canvasHeight),
        leadDestinationOffset: -40,
        joinDestinationOffset: 40
    )

    /// The yellow half sweeps down, the mascot squashes and springs up, then Set Route wipes in from the top.
    private static func LeadFrame(at time: Double) -> Frame {
        var frame = restFrame
        let expand = InOutCubic(Segment(time, 0, 0.42))
        frame.topSlab = Edge(left: Lerp(550, 964, expand), right: Lerp(480, 894, expand))

        let drop = Segment(time, 0, 0.24)
        frame.joinWord = Placement(x: 24, y: 588 + 60 * InCubic(drop), scale: 1, opacity: 1 - drop)

        let squash = sin(.pi * Segment(time, 0, 0.14))
        let rise = OutBack(Segment(time, 0.08, 0.44), overshoot: 1.6)
        let revealStart = RevealStart(of: .lead)
        let reveal = InOutQuart(Segment(time, revealStart, 1))
        frame.mascot = MascotPose(
            offset: 8 * squash - 28 * rise + 70 * reveal,
            scaleX: 1 + 0.05 * squash,
            scaleY: 1 - 0.07 * squash,
            rotation: 0
        )
        frame.leadWord = Placement(x: 24, y: 144 + 70 * reveal, scale: 1, opacity: 1)

        let edge = Lerp(0, canvasHeight + destinationTilt, reveal)
        frame.leadDestination = Edge(left: edge, right: edge - destinationTilt)
        frame.leadDestinationOffset = Lerp(-40, 0, OutCubic(Segment(time, revealStart, 1)))
        return frame
    }

    /// The split flips (JOIN grows, LEAD shrinks) while the crew pops up, yellow fills to the top, then Enter room
    /// code wipes up from the bottom.
    private static func JoinFrame(at time: Double) -> Frame {
        var frame = restFrame
        let flip = InOutCubic(Segment(time, 0, 0.36))
        frame.topSlab = Edge(left: Lerp(550, -5, flip), right: Lerp(480, -75, flip))

        let settle = OutBack(Segment(time, 0.06, 0.40), overshoot: 0.9)
        let fill = InOutCubic(Segment(time, 0.44, 0.70))
        let settledLeft = Lerp(928, 383, settle)
        let settledRight = Lerp(880, 335, settle)
        frame.bottomSlab = Edge(left: Lerp(settledLeft, -2, fill), right: Lerp(settledRight, -50, fill))

        let leave = Segment(time, 0.44, 0.58)
        frame.leadWord = Placement(
            x: Lerp(24, 22, flip),
            y: Lerp(144, 146, flip) - 30 * OutCubic(leave),
            scale: Lerp(1, 149.0 / 297.0, flip),
            opacity: 1 - leave
        )
        frame.mascot = MascotPose(offset: -80 * flip, scaleX: 1, scaleY: 1, rotation: 6 * flip)

        let revealStart = RevealStart(of: .join)
        let reveal = InOutQuart(Segment(time, revealStart, 1))
        frame.joinWord = Placement(
            x: Lerp(24, 10, flip),
            y: Lerp(588, 409, flip) - 60 * reveal,
            scale: Lerp(1, 2, flip),
            opacity: 1
        )

        let bounce = sin(.pi * fill)
        for (order, index) in crewPopOrder.enumerated() {
            let start = 0.10 + Double(order) * 0.03
            let pop = OutBack(Segment(time, start, start + 0.2), overshoot: 1.6)
            frame.crew[index] = CrewPose(offset: (1 - pop) * 140 - 10 * bounce - 80 * reveal, scale: 0.75 + 0.25 * pop)
        }

        let edge = Lerp(canvasHeight + destinationTilt, 0, reveal)
        frame.joinDestination = Edge(left: edge, right: edge - destinationTilt)
        frame.joinDestinationOffset = Lerp(40, 0, OutCubic(Segment(time, revealStart, 1)))
        return frame
    }

    // MARK: - Easing

    private static func Clamp(_ value: Double) -> Double {
        min(max(value, 0), 1)
    }

    /// How far `time` is through the part that runs from `start` to `end`, from 0 to 1.
    private static func Segment(_ time: Double, _ start: Double, _ end: Double) -> Double {
        Clamp((time - start) / (end - start))
    }

    private static func Lerp(_ start: Double, _ end: Double, _ amount: Double) -> Double {
        start + (end - start) * amount
    }

    private static func InOutCubic(_ value: Double) -> Double {
        value < 0.5 ? 4 * value * value * value : 1 - pow(-2 * value + 2, 3) / 2
    }

    private static func InOutQuart(_ value: Double) -> Double {
        value < 0.5 ? 8 * pow(value, 4) : 1 - pow(-2 * value + 2, 4) / 2
    }

    private static func OutCubic(_ value: Double) -> Double {
        1 - pow(1 - value, 3)
    }

    private static func InCubic(_ value: Double) -> Double {
        value * value * value
    }

    /// Goes a little past 1 and comes back, so things land with a small bounce.
    private static func OutBack(_ value: Double, overshoot: Double) -> Double {
        // Exact at both ends: the formula leaves a rounding error there, and the two flows must start equal.
        if value <= 0 { return 0 }
        if value >= 1 { return 1 }
        return 1 + (overshoot + 1) * pow(value - 1, 3) + overshoot * pow(value - 1, 2)
    }
}

//
//  TripStartIntro.swift
//  Lezgo
//
//  Created by Nathan Sudiara on 05/11/26.
//

import Foundation

/// The "Lez Go!" animation between Start Trip and the map, as a pure function of time, so a test can check any moment
/// and `TripStartIntroView` only has to draw it.
///
/// The robot rolls in and the letters grow as it passes. Then the robot rolls out, the map shows through the hole of
/// the O, and the camera goes through that hole. Distances are in points of the 402 pt wide Sketch frame.
enum TripStartIntro {
    /// The moment the robot starts to back up before rolling out.
    static let robotLeaves = 1.72
    /// The moment the robot passes the "!" on its way out.
    static let bangBump = 2.09
    /// The moment the camera starts to go through the O.
    static let zoomStarts = 2.5
    /// The moment the map under the logo starts to settle to its normal size.
    static let mapSettles = 2.8
    /// The moment the turn card, the bottom card, the cars and the map buttons come in.
    static let mapReveals = 2.92
    /// The moment the yellow is gone.
    static let duration = 3.06

    /// How far right the robot rolls out, past the edge of the frame.
    static let robotExitOffset = 480.0
    /// The radius of the hole of the O, slightly over the letter's own so no yellow shows along its inner edge.
    static let holeRadius = 33.0
    /// How far the logo grows: enough for the hole to pass every corner of the screen.
    static let finalZoom = 19.0

    /// How long after `startedAt` a phone still counts the trip as just started. Long enough for a member's phone to
    /// hear about the start, too short to play again when someone reopens the app on the road.
    private static let justStartedWindow: TimeInterval = 30

    /// Whether opening the map should play this animation.
    ///
    /// A session still in `LOBBY` is the one the Trip Room was holding when the trip started. Any other session comes
    /// from storage or from another phone's start, so `startedAt` tells whether the trip started just now.
    static func ShouldPlay(for trip: Trip, at date: Date) -> Bool {
        if trip.status == .lobby { return true }
        guard trip.status == .inTrip, let startedAt = trip.startedAt else { return false }
        return abs(date.timeIntervalSince(startedAt)) <= justStartedWindow
    }

    /// Something the map does at a moment of the animation, such as showing the cards.
    struct Step {
        /// Seconds after the map opened.
        let at: Double
        let run: () -> Void
    }

    /// Runs each step at its moment, in order. `sleep` waits that many seconds.
    ///
    /// When the task is cancelled the run stops and the remaining steps do not run. SwiftUI can restart the map's
    /// task while it presents the map over the Trip Room; the first run is then cancelled, and racing through its
    /// steps would remove the yellow before anyone saw it. The restarted run plays the animation instead.
    static func RunSteps(
        _ steps: [Step],
        sleep: (Double) async throws -> Void = { try await Task.sleep(for: .seconds($0)) }
    ) async {
        var elapsed = 0.0
        for step in steps {
            do {
                try await sleep(step.at - elapsed)
            } catch {
                return
            }
            guard Task.isCancelled == false else { return }
            elapsed = step.at
            step.run()
        }
    }

    /// The letters of the logo, each drawn on its own.
    enum Letter: CaseIterable, Hashable {
        case letterL, letterE, letterZ, letterG, letterO, bang

        /// When this letter starts to grow: as the robot passes it, from left to right.
        fileprivate var growsAt: Double {
            switch self {
            case .letterL, .letterG: 0.68
            case .letterE: 0.8
            case .letterZ: 0.94
            case .letterO: 1.08
            case .bang: 1.22
            }
        }
    }

    /// What the animation looks like at one moment.
    struct Frame: Equatable {
        var robotOffsetX: Double
        var robotRotationDegrees: Double
        var robotScaleX: Double
        var robotScaleY: Double
        /// The small jolt of the whole logo when the robot lands.
        var shakeOffsetY: Double
        var bangTiltDegrees: Double
        /// The hole through the yellow; 0 is closed.
        var holeRadius: Double
        var logoZoom: Double
        fileprivate var growths: [Letter: Double]

        /// How tall a letter is, from 0 (not there yet) to 1, going slightly over 1 as it springs up.
        func Growth(of letter: Letter) -> Double {
            growths[letter] ?? 0
        }
    }

    /// The frame at `time` seconds after the map opened. Times outside the animation give its first or last frame.
    static func FrameAt(_ time: Double) -> Frame {
        let time = min(max(time, 0), duration)
        let squash = RobotSquash(at: time)
        let zoom = LogoZoom(at: time)
        return Frame(
            robotOffsetX: RobotOffsetX(at: time),
            robotRotationDegrees: RobotRotation(at: time),
            robotScaleX: squash.scaleX,
            robotScaleY: squash.scaleY,
            shakeOffsetY: ShakeOffsetY(at: time),
            bangTiltDegrees: BangTilt(at: time),
            holeRadius: time < robotLeaves - 0.05 ? 0 : holeRadius * zoom,
            logoZoom: zoom,
            growths: Dictionary(uniqueKeysWithValues: Letter.allCases.map { letter in
                (letter, Ease.BackOut(Progress(time, from: letter.growsAt, duration: 0.36), overshoot: 2.6))
            })
        )
    }

    private static func RobotOffsetX(at time: Double) -> Double {
        if time < robotLeaves {
            return -440 * (1 - Ease.PowerOut(Progress(time, from: 0.6, duration: 0.66)))
        }
        if time < robotLeaves + 0.14 {
            return -18 * Ease.PowerOut(Progress(time, from: robotLeaves, duration: 0.14))
        }
        return -18 + (robotExitOffset + 18) * Ease.PowerIn(Progress(time, from: robotLeaves + 0.14, duration: 0.46), 2)
    }

    private static func RobotRotation(at time: Double) -> Double {
        if time < robotLeaves {
            return -900 * (1 - Ease.PowerOut(Progress(time, from: 0.6, duration: 0.66)))
        }
        if time < robotLeaves + 0.14 {
            return -32 * Ease.PowerOut(Progress(time, from: robotLeaves, duration: 0.14))
        }
        return -32 + 792 * Ease.PowerIn(Progress(time, from: robotLeaves + 0.14, duration: 0.46), 2)
    }

    /// Squashes on landing, springs back, and leans into the backing up before rolling out.
    private static func RobotSquash(at time: Double) -> (scaleX: Double, scaleY: Double) {
        let landing = 1.2
        if time < landing + 0.07 {
            let press = Progress(time, from: landing, duration: 0.07)
            return (1 + 0.14 * press, 1 - 0.12 * press)
        }
        if time < robotLeaves {
            let release = Ease.BackOut(Progress(time, from: landing + 0.07, duration: 0.2), overshoot: 3)
            return (1 + 0.14 * (1 - release), 1 - 0.12 * (1 - release))
        }
        if time < robotLeaves + 0.14 {
            return (1 - 0.06 * Ease.PowerOut(Progress(time, from: robotLeaves, duration: 0.14)), 1)
        }
        return (0.94 + 0.06 * Ease.PowerIn(Progress(time, from: robotLeaves + 0.14, duration: 0.46), 2), 1)
    }

    private static func ShakeOffsetY(at time: Double) -> Double {
        let elapsed = time - 1.2
        guard elapsed >= 0, elapsed < 0.19 else { return 0 }
        if elapsed < 0.04 { return 9 * elapsed / 0.04 }
        if elapsed < 0.09 { return 9 - 15 * (elapsed - 0.04) / 0.05 }
        if elapsed < 0.14 { return -6 + 9 * (elapsed - 0.09) / 0.05 }
        return 3 - 3 * (elapsed - 0.14) / 0.05
    }

    private static func BangTilt(at time: Double) -> Double {
        if time < bangBump { return 0 }
        if time < bangBump + 0.07 {
            return 15 * Ease.PowerOut(Progress(time, from: bangBump, duration: 0.07))
        }
        return 15 * (1 - Ease.ElasticOut(Progress(time, from: bangBump + 0.07, duration: 0.5)))
    }

    /// The logo shrinks a little as a run-up, then grows until the hole has passed every corner of the screen.
    private static func LogoZoom(at time: Double) -> Double {
        if time < zoomStarts {
            return 1 - 0.05 * Ease.PowerOut(Progress(time, from: zoomStarts - 0.12, duration: 0.12))
        }
        let zooming = Progress(time, from: zoomStarts, duration: duration - zoomStarts)
        return 0.95 + (finalZoom - 0.95) * Ease.PowerIn(zooming, 3)
    }

    /// How far along a step is, from 0 before it starts to 1 once it has finished.
    private static func Progress(_ time: Double, from start: Double, duration: Double) -> Double {
        min(max((time - start) / duration, 0), 1)
    }

    /// The speed curves of the animation; each takes and returns a progress from 0 to 1.
    private enum Ease {
        static func PowerIn(_ progress: Double, _ power: Double) -> Double {
            pow(progress, power)
        }

        /// Fast start, slow end.
        static func PowerOut(_ progress: Double) -> Double {
            1 - pow(1 - progress, 2)
        }

        /// Goes past the end and comes back, like a spring.
        static func BackOut(_ progress: Double, overshoot: Double) -> Double {
            let shifted = progress - 1
            return 1 + (overshoot + 1) * pow(shifted, 3) + overshoot * pow(shifted, 2)
        }

        /// Wobbles around the end and settles.
        static func ElasticOut(_ progress: Double) -> Double {
            guard progress > 0, progress < 1 else { return progress }
            let amplitude = 1.2
            let period = 0.35
            let shift = period / (2 * .pi) * asin(1 / amplitude)
            return amplitude * pow(2, -10 * progress) * sin((progress - shift) * 2 * .pi / period) + 1
        }
    }
}

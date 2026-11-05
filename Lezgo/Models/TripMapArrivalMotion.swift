//
//  TripMapArrivalMotion.swift
//  Lezgo
//
//  Created by Nathan Sudiara on 05/11/26.
//

import Foundation

/// How a new robot joins the row on the top card, as a pure function of time: it rolls in slowly from the left and
/// gently pushes the row to the right, one robot after another. Times are in seconds, distances in points.
enum TripMapArrivalMotion {
    /// The width of a robot on the card.
    static let robotSize = 64.0
    /// How long the new robot takes to roll in.
    static let rollDuration = 1.5
    /// The moment the new robot touches the row.
    static let contact = 1.0
    /// How far the row is pushed. Small on purpose: the driver should not be distracted.
    static let pushDistance = 8.0
    /// When the whole movement is over.
    static let duration = contact + pushDuration + settleDuration
        + rippleDelay * Double(TripMapArrivalProgress.maxRobots - 2)

    private static let pushDuration = 0.5
    private static let settleDuration = 0.7
    /// How much later the push reaches each next robot in the row.
    private static let rippleDelay = 0.05

    /// How far the new robot has come, from 0 to 1, slowing down as it arrives.
    static func RollProgress(at time: Double) -> Double {
        sin(Progress(time, from: 0, duration: rollDuration) * .pi / 2)
    }

    /// How far a robot in the row is pushed to the right. `rank` 0 is the one next to the new robot.
    static func PushOffset(at time: Double, rank: Int) -> Double {
        let start = contact + rippleDelay * Double(rank)
        if time < start + pushDuration {
            return pushDistance * sin(Progress(time, from: start, duration: pushDuration) * .pi / 2)
        }
        let settling = Progress(time, from: start + pushDuration, duration: settleDuration)
        return pushDistance * (1 + cos(settling * .pi)) / 2
    }

    /// How far a robot turns while rolling a distance, so it rolls instead of sliding.
    static func RollDegrees(over distance: Double) -> Double {
        distance / (.pi * robotSize) * 360
    }

    private static func Progress(_ time: Double, from start: Double, duration: Double) -> Double {
        min(max((time - start) / duration, 0), 1)
    }
}

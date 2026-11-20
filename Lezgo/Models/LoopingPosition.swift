//
//  LoopingPosition.swift
//  Lezgo
//

import Foundation

/// The maths of a carousel that loops: with `count` cards, the last card sits one step before the first, so a
/// swipe past either end comes back round.
///
/// A position is a continuous index: `1.0` shows the second card in the middle and `1.5` is halfway to the third.
/// It may be any number, below zero or past `count`; the cards are found by wrapping.
struct LoopingPosition: Equatable {
    let count: Int

    /// How long a flick keeps moving after the finger lifts, in seconds, when it picks the card to come to rest on.
    private static let flickDuration = 0.18

    /// How many cards card `index` is from the middle, between `-count / 2` and `count / 2`. Negative is to the left.
    func Offset(of index: Int, from position: Double) -> Double {
        guard count > 1 else { return 0 }
        let cardCount = Double(count)
        var offset = (Double(index) - position).truncatingRemainder(dividingBy: cardCount)
        if offset < 0 { offset += cardCount }
        if offset > cardCount / 2 { offset -= cardCount }
        return offset
    }

    /// The index, from `0` to `count - 1`, of the card nearest to the middle at `position`.
    func NearestIndex(to position: Double) -> Int {
        guard count > 1 else { return 0 }
        let whole = Int(position.rounded())
        return ((whole % count) + count) % count
    }

    /// The position a drag comes to rest on. The drag began at `start` and the finger lifted at `position`, moving at
    /// `velocity` cards per second (positive towards higher indexes). One swipe moves one card at most.
    func RestingPosition(from start: Double, releasedAt position: Double, velocity: Double) -> Double {
        guard count > 1 else { return start.rounded() }
        let first = start.rounded()
        let projected = (position + velocity * Self.flickDuration).rounded()
        return min(max(projected, first - 1), first + 1)
    }

    /// The position that puts card `index` in the middle, going the short way round from `position`.
    func Target(for index: Int, from position: Double) -> Double {
        guard count > 1 else { return position.rounded() }
        let cardCount = Double(count)
        var steps = Double(index - NearestIndex(to: position))
        if steps > cardCount / 2 { steps -= cardCount }
        if steps < -cardCount / 2 { steps += cardCount }
        return position.rounded() + steps
    }
}

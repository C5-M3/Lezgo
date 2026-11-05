//
//  TripMapArrivalTopCard.swift
//  Lezgo
//
//  Created by Nathan Sudiara on 05/11/26.
//

import SwiftUI

/// The top card once this phone's car has arrived: a robot per arrived car, up to five, and the count.
///
/// A new robot rolls in slowly from the left and gently pushes the row (`TripMapArrivalMotion`). Past five cars only
/// the count changes. With Reduce Motion the robots just appear.
struct TripMapArrivalTopCard: View {
    let progress: TripMapArrivalProgress

    /// The robots on the card, first to arrive first; the last one may still be rolling in.
    @State private var shownIDs: [UUID]
    /// The count on the card. It follows the robots, so it goes up when a robot touches the row.
    @State private var shownCount: Int
    @State private var rolling: Rolling?
    @State private var rowWidth = 0.0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .largeTitle) private var countSize = 46

    /// The turn each robot rests at, so the row looks lively as in the design.
    private static let restAngles = [0.0, -38, 32, -24, 18]
    private static let widestSpacing = 53.5
    /// The robot's body fills only part of its image; the rest is transparent margin.
    private static let imageSize = TripMapArrivalMotion.robotSize / 0.426

    /// The robot on its way in, and when it set off.
    private struct Rolling: Equatable {
        let id: UUID
        let startedAt: Date
    }

    init(progress: TripMapArrivalProgress) {
        self.progress = progress
        // The robots already there when the card opens just stand there. Only the newest, normally this phone's own
        // car, rolls in, unless the row is already full and past it.
        let isPastTheRow = progress.arrivedCount > TripMapArrivalProgress.maxRobots
        let shown = isPastTheRow ? progress.robots : Array(progress.robots.dropLast())
        _shownIDs = State(initialValue: shown.map(\.id))
        _shownCount = State(initialValue: isPastTheRow ? progress.arrivedCount : shown.count)
    }

    var body: some View {
        // Wider than the push, so a pushed robot never touches the count.
        HStack(spacing: 11) {
            TimelineView(.animation(paused: rolling == nil)) { context in
                Row(at: context.date)
            }
            .frame(maxWidth: .infinity, minHeight: TripMapArrivalMotion.robotSize)
            .onGeometryChange(for: CGFloat.self, of: \.size.width) { rowWidth = Double($0) }

            Text(verbatim: "\(shownCount)/\(progress.totalCount)")
                .font(.system(size: countSize, weight: .black))
                .foregroundStyle(.white)
                .lineLimit(1)
                .contentTransition(.numericText())
                .animation(reduceMotion ? nil : .easeOut(duration: 0.4), value: shownCount)
                .layoutPriority(1)
        }
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, minHeight: 113)
        .background(.black, in: .rect(cornerRadius: 30))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(.tripMapArrivedCount(progress.arrivedCount, progress.totalCount)))
        .task(id: progress) { await PlayArrivals() }
    }

    private func Row(at date: Date) -> some View {
        let elapsed = rolling.map { date.timeIntervalSince($0.startedAt) } ?? TripMapArrivalMotion.duration
        return ZStack(alignment: .trailing) {
            ForEach(Array(shownIDs.enumerated()), id: \.element) { index, id in
                let placement = Placement(of: id, at: index, elapsed: elapsed)
                Image(RobotImage(of: id))
                    .resizable()
                    .accessibilityHidden(true)
                    .frame(width: Self.imageSize, height: Self.imageSize)
                    .rotationEffect(.degrees(placement.rotation))
                    .frame(width: TripMapArrivalMotion.robotSize, height: TripMapArrivalMotion.robotSize)
                    .offset(x: placement.offsetX)
                    // The first to arrive stays on top, as in the design.
                    .zIndex(Double(-index))
            }
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
        // When the fifth robot squeezes in, the row closes up as slowly as the robot arrives.
        .animation(reduceMotion ? nil : .easeInOut(duration: TripMapArrivalMotion.rollDuration), value: Spacing())
    }

    /// The distance between two robots: closer together when the row would otherwise leave the card.
    private func Spacing() -> Double {
        guard shownIDs.count > 1 else { return Self.widestSpacing }
        return min(Self.widestSpacing, (rowWidth - TripMapArrivalMotion.robotSize) / Double(shownIDs.count - 1))
    }

    private func Placement(of id: UUID, at index: Int, elapsed: Double) -> (offsetX: Double, rotation: Double) {
        let rest = Self.restAngles[index % Self.restAngles.count]
        let place = -Double(index) * Spacing()
        if id == rolling?.id {
            // It starts past the left edge of the card and the screen.
            let distance = rowWidth + place + TripMapArrivalMotion.robotSize + 40
            let remaining = distance * (1 - TripMapArrivalMotion.RollProgress(at: elapsed))
            return (place - remaining, rest - TripMapArrivalMotion.RollDegrees(over: remaining))
        }
        guard rolling != nil else { return (place, rest) }
        let push = TripMapArrivalMotion.PushOffset(at: elapsed, rank: shownIDs.count - 2 - index)
        return (place + push, rest + TripMapArrivalMotion.RollDegrees(over: push))
    }

    private func RobotImage(of id: UUID) -> ImageResource {
        switch progress.robots.first(where: { $0.id == id })?.carColor ?? .yellow {
        case .yellow: .frontballActiveYellow
        case .purple: .frontballActivePurple
        case .pink: .frontballActivePink
        case .blue: .frontballActiveBlue
        case .green: .frontballActiveGreen
        }
    }

    /// Brings the card up to date, one robot at a time. When a new arrival restarts this, a robot on its way finishes
    /// its roll instead of starting over.
    private func PlayArrivals() async {
        let current = progress.robots.map(\.id)
        shownIDs.removeAll { current.contains($0) == false }
        if let rolling, current.contains(rolling.id) == false { self.rolling = nil }
        if reduceMotion {
            shownIDs = current
            rolling = nil
            shownCount = progress.arrivedCount
            return
        }
        if let rolling, await Finish(rolling) == false { return }
        while let next = current.first(where: { shownIDs.contains($0) == false }) {
            let started = Rolling(id: next, startedAt: .now)
            shownIDs.append(next)
            rolling = started
            if await Finish(started) == false { return }
        }
        shownCount = progress.arrivedCount
    }

    /// Waits out a robot's roll, raising the count when it touches the row. `false` when a new arrival interrupted.
    private func Finish(_ roll: Rolling) async -> Bool {
        let elapsed = Date.now.timeIntervalSince(roll.startedAt)
        if elapsed < TripMapArrivalMotion.contact {
            guard await Wait(TripMapArrivalMotion.contact - elapsed) else { return false }
        }
        shownCount = shownIDs.count
        let sinceContact = max(elapsed, TripMapArrivalMotion.contact)
        guard await Wait(TripMapArrivalMotion.duration - sinceContact) else { return false }
        rolling = nil
        return true
    }

    private func Wait(_ seconds: Double) async -> Bool {
        (try? await Task.sleep(for: .seconds(seconds))) != nil
    }
}

#Preview("Robots arriving one by one") {
    @Previewable @State var arrived = 1
    @Previewable @State var ids = (0..<5).map { _ in UUID() }
    let robots: [TripMapCarPin.CarColor] = [.yellow, .blue, .pink, .purple, .green]

    VStack(spacing: 24) {
        TripMapArrivalTopCard(
            progress: TripMapArrivalProgress(
                robots: zip(ids, robots).prefix(arrived).map { .init(id: $0, carColor: $1) },
                arrivedCount: arrived,
                totalCount: 10
            )
        )
        Button("Next car arrives") { arrived = min(arrived + 1, 10) }
    }
    .padding(12)
}

#Preview("Full row, largest text") {
    TripMapArrivalTopCard(
        progress: TripMapArrivalProgress(
            robots: [.yellow, .blue, .pink, .purple, .green].map { .init(id: UUID(), carColor: $0) },
            arrivedCount: 10,
            totalCount: 10
        )
    )
    .padding(12)
    .dynamicTypeSize(.accessibility5)
}

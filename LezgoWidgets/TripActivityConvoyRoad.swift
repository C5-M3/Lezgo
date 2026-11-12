//
//  TripActivityConvoyRoad.swift
//  LezgoWidgets
//
//  Created by Nathan Sudiara on 12/11/26.
//

import SwiftUI

/// The group as robots on a little road to the chequered flag, with every checkpoint as a numbered post. Each one is
/// placed by how far along the route it is; the part this car has driven is tinted yellow.
struct TripActivityConvoyRoad: View {
    let robots: [TripActivityAttributes.Robot]
    let stops: [TripActivityAttributes.Stop]
    var robotSize: CGFloat = 28

    private var myProgress: Double {
        robots.first { $0.isMe }?.progress ?? 0
    }

    var body: some View {
        ZStack(alignment: .leading) {
            TripActivityRoadTrack(driven: myProgress, height: robotSize * 0.32)
            ConvoyLayout {
                ForEach(stops) { stop in
                    TripActivityStopPost(stop: stop, size: robotSize * 0.6)
                        .layoutValue(key: ConvoyProgress.self, value: stop.progress)
                }
                Image(systemName: "flag.checkered")
                    .font(.system(size: robotSize * 0.6, weight: .black))
                    .foregroundStyle(Color(.brandYellow))
                    .accessibilityHidden(true)
                    .layoutValue(key: ConvoyProgress.self, value: 1)
                ForEach(robots.sorted { $0.isMe == false && $1.isMe }) { robot in
                    TripActivityConvoyRobot(robot: robot, size: robotSize)
                        .layoutValue(key: ConvoyProgress.self, value: robot.progress)
                }
            }
        }
        .frame(height: robotSize * 1.45)
        .accessibilityHidden(true)
    }
}

/// The grey road with a dashed middle line and the driven part in yellow.
private struct TripActivityRoadTrack: View {
    let driven: Double
    let height: CGFloat

    var body: some View {
        Capsule()
            .fill(.white.opacity(0.13))
            .overlay {
                Capsule()
                    .fill(Color(.brandYellow).opacity(0.28))
                    .scaleEffect(x: max(driven, 0.02), anchor: .leading)
            }
            .overlay {
                Rectangle()
                    .stroke(.white.opacity(0.18), style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                    .frame(height: 0)
                    .padding(.horizontal, height)
            }
            .frame(height: height)
    }
}

/// A checkpoint: a white post with its number, grey with a tick once the group has passed it.
private struct TripActivityStopPost: View {
    let stop: TripActivityAttributes.Stop
    let size: CGFloat

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Circle().fill(stop.isVisited ? Color.white.opacity(0.35) : .white)
                if stop.isVisited {
                    Image(systemName: "checkmark")
                        .font(.system(size: size * 0.5, weight: .black))
                } else {
                    Text(stop.number, format: .number)
                        .font(.system(size: size * 0.62, weight: .black, design: .rounded))
                }
            }
            .foregroundStyle(Color(.tripCard))
            .frame(width: size, height: size)
            Rectangle()
                .fill(stop.isVisited ? Color.white.opacity(0.35) : .white)
                .frame(width: 2, height: size * 0.55)
        }
        .offset(y: -size * 0.45)
        .accessibilityHidden(true)
    }
}

/// One robot on the road. The leader wears a crown, a car with an alert gets a red dashed ring and a "!", and a
/// robot standing for several cars close together shows how many more there are.
private struct TripActivityConvoyRobot: View {
    let robot: TripActivityAttributes.Robot
    let size: CGFloat

    private var side: CGFloat {
        robot.isMe ? size * 1.3 : size
    }

    var body: some View {
        Image(robot.isMe ? robot.color.glowingRobot : robot.color.robot)
            .resizable()
            .scaledToFit()
            .frame(width: side, height: side)
            .rotationEffect(.degrees(90))
            .accessibilityHidden(true)
            .background {
                if robot.isAlerting {
                    Circle()
                        .strokeBorder(Color(.tripAlertRed), style: StrokeStyle(lineWidth: 2, dash: [3, 2]))
                        .padding(-2)
                }
            }
            .overlay(alignment: .top) {
                if robot.isLeader {
                    Image(systemName: "crown.fill")
                        .font(.system(size: size * 0.38))
                        .foregroundStyle(Color(.brandYellow))
                        .offset(y: -size * 0.32)
                        .accessibilityHidden(true)
                }
            }
            .overlay(alignment: .topTrailing) {
                TripActivityRobotBadge(robot: robot, size: size * 0.55)
            }
            // A car with an alert drops just off the road, so it stands apart from the cars around it.
            .offset(y: robot.isAlerting ? size * 0.3 : 0)
    }
}

/// "!" for a car with an alert, "+2" for a robot that stands for 3 cars.
private struct TripActivityRobotBadge: View {
    let robot: TripActivityAttributes.Robot
    let size: CGFloat

    var body: some View {
        if robot.isAlerting {
            Text(verbatim: "!")
                .font(.system(size: size * 0.75, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .frame(width: size, height: size)
                .background(Color(.tripAlertRed), in: .circle)
                .offset(x: size * 0.3, y: -size * 0.3)
        } else if robot.groupCount > 1 {
            Text(verbatim: "+\(robot.groupCount - 1)")
                .font(.system(size: size * 0.65, weight: .black, design: .rounded))
                .foregroundStyle(Color(.tripCard))
                .padding(.horizontal, 3)
                .frame(minWidth: size, minHeight: size)
                .background(.white, in: .capsule)
                .offset(x: size * 0.4, y: -size * 0.3)
        }
    }
}

/// How far along the road a view sits, 0 to 1.
nonisolated private struct ConvoyProgress: LayoutValueKey {
    static let defaultValue = 0.0
}

/// Places each view along the width by its progress, centred on its spot and kept inside the road.
nonisolated private struct ConvoyLayout: Layout {
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let height = subviews.map { $0.sizeThatFits(.unspecified).height }.max() ?? 0
        return CGSize(width: proposal.width ?? 200, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            let spot = bounds.minX + size.width / 2 + (bounds.width - size.width) * subview[ConvoyProgress.self]
            subview.place(at: CGPoint(x: spot, y: bounds.midY), anchor: .center, proposal: ProposedViewSize(size))
        }
    }
}

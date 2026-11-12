//
//  TripActivityConvoyRoad.swift
//  LezgoWidgets
//
//  Created by Nathan Sudiara on 12/11/26.
//

import SwiftUI

/// The group as robots on a little road to the chequered flag, each placed by how far along the route it is.
struct TripActivityConvoyRoad: View {
    let robots: [TripActivityAttributes.Robot]
    var robotSize: CGFloat = 30

    var body: some View {
        ZStack(alignment: .leading) {
            Capsule()
                .fill(.white.opacity(0.12))
                .frame(height: robotSize * 0.4)
                .padding(.trailing, robotSize * 0.6)
            ConvoyLayout {
                ForEach(robots.sorted { $0.isMe == false && $1.isMe }) { robot in
                    TripActivityConvoyRobot(robot: robot, size: robotSize)
                        .layoutValue(key: ConvoyProgress.self, value: robot.progress)
                }
                Image(systemName: "flag.checkered")
                    .font(.system(size: robotSize * 0.55, weight: .black))
                    .foregroundStyle(Color(.brandYellow))
                    .layoutValue(key: ConvoyProgress.self, value: 1)
            }
        }
        .frame(height: robotSize * 1.3)
        .accessibilityHidden(true)
    }
}

/// One robot on the road: the leader wears a crown, a car with an alert turns off the road in a red ring.
private struct TripActivityConvoyRobot: View {
    let robot: TripActivityAttributes.Robot
    let size: CGFloat

    var body: some View {
        Image(robot.isMe ? robot.color.glowingRobot : robot.color.robot)
            .resizable()
            .scaledToFit()
            .frame(width: robot.isMe ? size * 1.3 : size, height: robot.isMe ? size * 1.3 : size)
            .rotationEffect(.degrees(robot.isAlerting ? 145 : 90))
            .accessibilityHidden(true)
            .background {
                if robot.isAlerting {
                    Circle()
                        .strokeBorder(Color(.tripAlertRed), style: StrokeStyle(lineWidth: 2, dash: [3, 2]))
                }
            }
            .offset(y: robot.isAlerting ? size * 0.3 : 0)
            .overlay(alignment: .top) {
                if robot.isLeader {
                    Image(systemName: "crown.fill")
                        .font(.system(size: size * 0.35))
                        .foregroundStyle(Color(.brandYellow))
                        .offset(y: -size * 0.3)
                        .accessibilityHidden(true)
                }
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

//
//  TripActivityLegRoad.swift
//  LezgoWidgets
//
//  Created by Nathan Sudiara on 12/11/26.
//

import SwiftUI

/// The current leg as a line from a ring (the last stop, or the start) to a flag (the next stop), with every car's
/// robot on it. The line is yellow up to the car furthest ahead.
struct TripActivityLegRoad: View {
    let state: TripActivityAttributes.ContentState
    var robotSize: CGFloat = 36

    private var lineWidth: CGFloat {
        max(robotSize / 9, 3)
    }

    var body: some View {
        ZStack {
            TripActivityLegLine(reached: state.reached, lineWidth: lineWidth)
                .padding(.horizontal, robotSize / 4)
            LegLayout {
                Circle()
                    .strokeBorder(Color(.brandYellow), lineWidth: lineWidth)
                    .background(Circle().fill(Color(.tripCard)))
                    .frame(width: robotSize / 2, height: robotSize / 2)
                    .layoutValue(key: LegProgress.self, value: 0)
                Image(systemName: "flag.checkered")
                    .font(.system(size: robotSize * 0.7, weight: .bold))
                    .foregroundStyle(Color(.brandYellow))
                    .layoutValue(key: LegProgress.self, value: 1)
                // This phone's robot goes last, so it is drawn on top of the others.
                ForEach(state.robots.sorted { $0.isMe == false && $1.isMe }) { robot in
                    TripActivityRobotHead(color: robot.color, isOnline: robot.isOnline, size: robotSize)
                        .layoutValue(key: LegProgress.self, value: robot.progress)
                }
            }
        }
        .frame(height: robotSize)
        .accessibilityHidden(true)
    }
}

/// Grey line with the reached part in yellow.
private struct TripActivityLegLine: View {
    let reached: Double
    let lineWidth: CGFloat

    var body: some View {
        Capsule()
            .fill(.white.opacity(0.18))
            .overlay {
                Capsule()
                    .fill(Color(.brandYellow))
                    .scaleEffect(x: max(reached, 0.01), anchor: .leading)
            }
            .frame(height: lineWidth)
    }
}

/// How far along the leg a view sits, 0 to 1.
nonisolated private struct LegProgress: LayoutValueKey {
    static let defaultValue = 0.0
}

/// Places each view along the width by its progress, centred on its spot and kept inside the road.
nonisolated private struct LegLayout: Layout {
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let height = subviews.map { $0.sizeThatFits(.unspecified).height }.max() ?? 0
        return CGSize(width: proposal.width ?? 200, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            let spot = bounds.minX + size.width / 2 + (bounds.width - size.width) * subview[LegProgress.self]
            subview.place(at: CGPoint(x: spot, y: bounds.midY), anchor: .center, proposal: ProposedViewSize(size))
        }
    }
}

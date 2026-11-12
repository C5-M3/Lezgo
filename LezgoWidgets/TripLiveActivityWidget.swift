//
//  TripLiveActivityWidget.swift
//  LezgoWidgets
//
//  Created by Nathan Sudiara on 12/11/26.
//

import SwiftUI
import WidgetKit

/// The trip's Live Activity on the Lock Screen, in the Dynamic Island, on a Mac, on the CarPlay dashboard and on
/// Apple Watch (ADR 0027).
struct TripLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TripActivityAttributes.self) { context in
            TripActivityPresentation(state: context.state)
                .activityBackgroundTint(Color(.tripCard))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            let state = context.state
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Text(state.distanceText ?? "")
                        .font(.system(size: 24, weight: .bold))
                        .fixedSize()
                        .padding(.leading, 6)
                        .padding(.top, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    TripActivityTime(state: state, size: 24)
                        .padding(.trailing, 6)
                        .padding(.top, 4)
                }
                // The bottom spans the whole width under the camera, so a long stop name is not squeezed.
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 8) {
                        Text(state.title)
                            .font(.system(size: 16, weight: .semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        TripActivityLegRoad(state: state, robotSize: 28)
                        // Pulled in from the island's rounded bottom corners, which cut the labels off.
                        TripActivityLegLabels(state: state)
                            .padding(.horizontal, 10)
                    }
                    .padding(.horizontal, 6)
                    .padding(.bottom, 4)
                }
            } compactLeading: {
                TripActivityRobotHead(color: state.myColor, size: 24)
            } compactTrailing: {
                TripActivityTime(state: state, size: 15, isShort: true)
            } minimal: {
                TripActivityRobotHead(color: state.myColor, size: 24)
            }
            // Keeps everything away from the island's rounded corners, which cut it off otherwise.
            .contentMargins([.leading, .trailing], 20, for: .expanded)
            .contentMargins(.bottom, 18, for: .expanded)
            .keylineTint(Color(.brandYellow))
        }
        // CarPlay's dashboard and Apple Watch's Smart Stack show the small tile instead of the Lock Screen card.
        .supplementalActivityFamilies([.small])
    }
}

/// Picks the Lock Screen card or the small tile, and paints the card's own dark background: a Mac and the Lock
/// Screen's glass do not always use the background tint, which left the card grey.
private struct TripActivityPresentation: View {
    let state: TripActivityAttributes.ContentState
    @Environment(\.activityFamily) private var family

    var body: some View {
        switch family {
        case .small:
            TripActivitySmallView(state: state)
        default:
            TripActivityLockScreenView(state: state)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.tripCard))
        }
    }
}

private extension TripActivityAttributes.ContentState {
    static let preview = TripActivityAttributes.ContentState(
        stage: .driving,
        title: "To Rest Area KM 57",
        timeText: "50 min",
        shortTimeText: "50 min",
        distanceText: "12 km",
        countText: nil,
        legStartLabel: "Start",
        legEndLabel: "Stop 1 of 2",
        robots: [
            PreviewRobot(.green, at: 0.2, isOnline: false),
            PreviewRobot(.blue, at: 0.52, isOnline: false),
            PreviewRobot(.purple, at: 0.6, isMe: true),
            PreviewRobot(.pink, at: 0.68),
            PreviewRobot(.yellow, at: 0.74)
        ],
        reached: 0.74,
        myColor: .purple
    )

    static func PreviewRobot(
        _ color: TripActivityAttributes.RobotColor,
        at progress: Double,
        isMe: Bool = false,
        isOnline: Bool = true
    ) -> TripActivityAttributes.Robot {
        TripActivityAttributes.Robot(id: UUID(), color: color, progress: progress, isMe: isMe, isOnline: isOnline)
    }

    static var previewLastLeg: Self {
        var state = preview
        state.title = "To Ciputra World Surabaya"
        state.timeText = "1 hr, 18 min"
        state.shortTimeText = "1:18"
        state.legStartLabel = "Rest Area KM 57"
        state.legEndLabel = "Destination"
        return state
    }

    static var previewArrived: Self {
        var state = previewLastLeg
        state.stage = .arrived
        state.title = "You have arrived"
        state.timeText = nil
        state.shortTimeText = nil
        state.distanceText = nil
        state.countText = "3/4"
        state.legStartLabel = "Waiting for everyone to arrive"
        state.reached = 1
        return state
    }
}

#Preview("Lock Screen", as: .content, using: TripActivityAttributes(title: "To Ciputra World")) {
    TripLiveActivityWidget()
} contentStates: {
    TripActivityAttributes.ContentState.preview
    TripActivityAttributes.ContentState.previewLastLeg
    TripActivityAttributes.ContentState.previewArrived
}

#Preview("Island expanded", as: .dynamicIsland(.expanded), using: TripActivityAttributes(title: "To Ciputra")) {
    TripLiveActivityWidget()
} contentStates: {
    TripActivityAttributes.ContentState.preview
    TripActivityAttributes.ContentState.previewArrived
}

#Preview("Island compact", as: .dynamicIsland(.compact), using: TripActivityAttributes(title: "To Ciputra")) {
    TripLiveActivityWidget()
} contentStates: {
    TripActivityAttributes.ContentState.preview
    TripActivityAttributes.ContentState.previewLastLeg
    TripActivityAttributes.ContentState.previewArrived
}

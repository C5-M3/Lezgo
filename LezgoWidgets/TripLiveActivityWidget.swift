//
//  TripLiveActivityWidget.swift
//  LezgoWidgets
//
//  Created by Nathan Sudiara on 12/11/26.
//

import SwiftUI
import WidgetKit

/// The trip's Live Activity on the Lock Screen, in the Dynamic Island and on the CarPlay dashboard (ADR 0027).
struct TripLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TripActivityAttributes.self) { context in
            TripActivityLockScreenView(state: context.state)
                .activityBackgroundTint(Color(.tripCard))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            let state = context.state
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(TripActivitySticker.For(state))
                        .resizable()
                        .scaledToFit()
                        .frame(width: 44, height: 44)
                        .rotationEffect(.degrees(state.alert == nil ? -8 : 10))
                        .padding(.leading, 4)
                        .accessibilityHidden(true)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    TripActivityIslandTrailing(state: state)
                }
                DynamicIslandExpandedRegion(.center) {
                    TripActivityIslandCenter(state: state)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    TripActivityIslandBottom(state: state)
                }
            } compactLeading: {
                TripActivityCompactLeading(state: state)
            } compactTrailing: {
                TripActivityCompactTrailing(state: state)
            } minimal: {
                Image(state.alert?.color.robot ?? state.myColor.glowingRobot)
                    .resizable()
                    .scaledToFit()
                    .rotationEffect(.degrees(state.alert == nil ? 0 : 35))
                    .accessibilityHidden(true)
            }
            // Keeps everything away from the island's rounded corners, which cut it off otherwise.
            .contentMargins([.leading, .trailing], 20, for: .expanded)
            .contentMargins(.bottom, 14, for: .expanded)
            .keylineTint(state.alert == nil ? Color(.brandYellow) : Color(.tripAlertRed))
        }
    }
}

/// Time left and the arrival time, or the arrival count once arrived.
private struct TripActivityIslandTrailing: View {
    let state: TripActivityAttributes.ContentState

    var body: some View {
        VStack(alignment: .trailing, spacing: 1) {
            if let arrival = state.arrival {
                Text(arrival.countText)
                    .font(.system(size: 16, weight: .black, design: .rounded))
                    .foregroundStyle(Color(.tripCard))
                    .padding(.horizontal, 10)
                    .frame(height: 28)
                    .background(Color(.brandYellow), in: .capsule)
            } else {
                Text(state.shortTimeLeftText ?? "")
                    .font(.system(size: 19, weight: .black, design: .rounded))
                    .fixedSize()
                Text(state.arrivalTimeText ?? "")
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
        .padding(.trailing, 4)
        .lineLimit(1)
    }
}

/// The alert, the arrival or the next turn, under the camera.
private struct TripActivityIslandCenter: View {
    let state: TripActivityAttributes.ContentState

    var body: some View {
        VStack(spacing: 2) {
            if let alert = state.alert {
                Text(alert.text)
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .foregroundStyle(Color(.tripAlertRed))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                Text(alert.detail ?? "")
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white.opacity(0.8))
            } else if let arrival = state.arrival {
                Text(arrival.title)
                    .font(.system(size: 20, weight: .black, design: .rounded))
                Text(state.headline)
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white.opacity(0.6))
            } else if let turn = state.turn {
                Label(turn.distanceText, systemImage: turn.symbolName)
                    .font(.system(size: 21, weight: .black, design: .rounded))
                    .foregroundStyle(Color(.brandYellow))
                Text(turn.instruction)
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white.opacity(0.85))
            } else {
                Text(state.statusText ?? "")
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.8)
    }
}

/// The convoy road, then the next stop or the group, and Mute.
private struct TripActivityIslandBottom: View {
    let state: TripActivityAttributes.ContentState

    private var caption: String {
        if state.alert != nil || state.arrival != nil { return state.groupText }
        return state.headline
    }

    var body: some View {
        VStack(spacing: 4) {
            TripActivityConvoyRoad(robots: state.robots, stops: state.stops, robotSize: 22)
            HStack {
                Text(caption)
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .foregroundStyle(state.isGroupWarning ? Color(.tripAlertRed) : Color(.brandYellow))
                    .lineLimit(1)
                Spacer(minLength: 8)
                TripActivityMuteButton(state: state)
            }
            .padding(.horizontal, 4)
        }
    }
}

/// Your robot and the next turn; while an alert is on, that car's robot swerves in with its name.
private struct TripActivityCompactLeading: View {
    let state: TripActivityAttributes.ContentState

    var body: some View {
        HStack(spacing: 3) {
            if let alert = state.alert {
                Image(alert.color.robot)
                    .resizable()
                    .scaledToFit()
                    .rotationEffect(.degrees(35))
                    .accessibilityHidden(true)
                Text(alert.carName)
                    .foregroundStyle(Color(.tripAlertRed))
            } else if state.arrival != nil {
                Image(.mascotCheer)
                    .resizable()
                    .scaledToFit()
                    .accessibilityHidden(true)
            } else {
                Image(state.myColor.glowingRobot)
                    .resizable()
                    .scaledToFit()
                    .accessibilityHidden(true)
                if let turn = state.turn {
                    // No arrow here: beside the camera there is only room for the robot and the distance.
                    Text(turn.distanceText)
                        .foregroundStyle(Color(.brandYellow))
                        .fixedSize()
                } else if let status = state.statusText {
                    Text(status)
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
        }
        .font(.system(size: 14, weight: .black, design: .rounded))
        .lineLimit(1)
    }
}

/// The time left, the arrival count, or the alert in a word.
private struct TripActivityCompactTrailing: View {
    let state: TripActivityAttributes.ContentState

    var body: some View {
        Group {
            if let alert = state.alert {
                Text(alert.shortText)
                    .foregroundStyle(Color(.tripAlertRed))
            } else if let arrival = state.arrival {
                Text(arrival.countText)
                    .foregroundStyle(Color(.brandYellow))
            } else {
                Text(state.shortTimeLeftText ?? "")
            }
        }
        .font(.system(size: 14, weight: .black, design: .rounded))
        .lineLimit(1)
    }
}

private extension TripActivityAttributes.ContentState {
    static let preview = TripActivityAttributes.ContentState(
        stage: .driving,
        turn: TripActivityAttributes.Turn(
            symbolName: "arrow.turn.up.right", distanceText: "240 m", instruction: "Turn right onto Jl. Raya Darmo"
        ),
        headline: "Next stop · Rest area KM 57",
        statusText: nil,
        timeLeftText: "33 min",
        shortTimeLeftText: "33 min",
        arrivalTimeText: "10.17",
        detailText: "12 km · Arrive 10.17",
        groupText: "Following Than",
        isGroupWarning: false,
        alert: nil,
        arrival: nil,
        robots: [
            PreviewRobot(.green, at: 0.08, groupCount: 3),
            PreviewRobot(.blue, at: 0.26, isMe: true),
            PreviewRobot(.yellow, at: 0.38, isLeader: true)
        ],
        stops: [
            TripActivityAttributes.Stop(number: 1, progress: 0.22, isVisited: true),
            TripActivityAttributes.Stop(number: 2, progress: 0.55, isVisited: false),
            TripActivityAttributes.Stop(number: 3, progress: 0.76, isVisited: false)
        ],
        myColor: .blue,
        isLeader: false,
        isMuted: false,
        muteLabel: "Mute"
    )

    static func PreviewRobot(
        _ color: TripActivityAttributes.RobotColor,
        at progress: Double,
        isMe: Bool = false,
        isLeader: Bool = false,
        groupCount: Int = 1
    ) -> TripActivityAttributes.Robot {
        TripActivityAttributes.Robot(
            id: UUID(), color: color, progress: progress, isMe: isMe, isLeader: isLeader, isAlerting: false,
            groupCount: groupCount
        )
    }

    static var previewAlert: Self {
        var state = preview
        state.alert = TripActivityAttributes.Alert(
            text: "Than has stopped", shortText: "Stopped", detail: "400 m behind you", color: .pink, carName: "Than"
        )
        state.robots[0] = PreviewRobot(.pink, at: 0.08)
        state.robots[0].isAlerting = true
        state.isGroupWarning = true
        state.groupText = "4/5 on route"
        return state
    }

    static var previewArrived: Self {
        var state = preview
        state.stage = .arrived
        state.turn = nil
        state.headline = "Ciputra World Surabaya"
        state.arrival = TripActivityAttributes.Arrival(
            title: "You have arrived", countText: "3/4", detail: "Waiting for everyone to arrive"
        )
        return state
    }
}

#Preview("Lock Screen", as: .content, using: TripActivityAttributes(title: "To Ciputra World")) {
    TripLiveActivityWidget()
} contentStates: {
    TripActivityAttributes.ContentState.preview
    TripActivityAttributes.ContentState.previewAlert
    TripActivityAttributes.ContentState.previewArrived
}

#Preview("Island expanded", as: .dynamicIsland(.expanded), using: TripActivityAttributes(title: "To Ciputra")) {
    TripLiveActivityWidget()
} contentStates: {
    TripActivityAttributes.ContentState.preview
    TripActivityAttributes.ContentState.previewAlert
    TripActivityAttributes.ContentState.previewArrived
}

#Preview("Island compact", as: .dynamicIsland(.compact), using: TripActivityAttributes(title: "To Ciputra")) {
    TripLiveActivityWidget()
} contentStates: {
    TripActivityAttributes.ContentState.preview
    TripActivityAttributes.ContentState.previewAlert
    TripActivityAttributes.ContentState.previewArrived
}

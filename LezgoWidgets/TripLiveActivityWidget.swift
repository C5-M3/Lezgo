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
            TripActivityLockScreenView(title: context.attributes.title, state: context.state)
                .activityBackgroundTint(Color(.tripCard))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            let state = context.state
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(state.alert?.color.sticker ?? (state.arrival == nil ? state.myColor.sticker : .mascotCheer))
                        .resizable()
                        .scaledToFit()
                        .frame(width: 52, height: 52)
                        .rotationEffect(.degrees(-8))
                        .accessibilityHidden(true)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(state.shortTimeLeftText ?? state.arrival?.countText ?? "")
                        .font(.system(.title2, design: .rounded, weight: .black))
                        .foregroundStyle(.white)
                }
                DynamicIslandExpandedRegion(.center) {
                    TripActivityIslandCenter(title: context.attributes.title, state: state)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 4) {
                        TripActivityConvoyRoad(robots: state.robots, robotSize: 24)
                        HStack {
                            Text(state.nextStopText ?? state.groupText)
                                .font(.system(.caption, design: .rounded, weight: .heavy))
                                .foregroundStyle(state.isGroupWarning ? Color(.tripAlertRed) : Color(.brandYellow))
                                .lineLimit(1)
                            Spacer()
                            TripActivityMuteButton(state: state)
                        }
                    }
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
            .keylineTint(state.alert == nil ? Color(.brandYellow) : Color(.tripAlertRed))
        }
    }
}

/// The alert, the arrival or the next turn in the middle of the expanded island.
private struct TripActivityIslandCenter: View {
    let title: String
    let state: TripActivityAttributes.ContentState

    var body: some View {
        VStack(spacing: 2) {
            if let alert = state.alert {
                Text(alert.text)
                    .font(.system(.headline, design: .rounded, weight: .black))
                    .foregroundStyle(Color(.tripAlertRed))
            } else if let arrival = state.arrival {
                Text(arrival.title)
                    .font(.system(.title3, design: .rounded, weight: .black))
            } else if let turn = state.turn {
                Label(turn.distanceText, systemImage: turn.symbolName)
                    .font(.system(.title2, design: .rounded, weight: .black))
                    .foregroundStyle(Color(.brandYellow))
                Text(turn.instruction)
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
            } else {
                Text(title)
                    .font(.system(.headline, design: .rounded, weight: .black))
            }
        }
        .lineLimit(1)
        .multilineTextAlignment(.center)
    }
}

/// Your robot and the next turn; while an alert is on, that car's robot swerves in with its name.
private struct TripActivityCompactLeading: View {
    let state: TripActivityAttributes.ContentState

    var body: some View {
        HStack(spacing: 2) {
            if let alert = state.alert {
                Image(alert.color.robot)
                    .resizable()
                    .scaledToFit()
                    .rotationEffect(.degrees(35))
                    .accessibilityHidden(true)
                Text(alert.carName)
                    .foregroundStyle(Color(.tripAlertRed))
            } else if state.stage == .arrived {
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
                    Label(turn.distanceText, systemImage: turn.symbolName)
                        .foregroundStyle(Color(.brandYellow))
                }
            }
        }
        .font(.system(.footnote, design: .rounded, weight: .black))
        .lineLimit(1)
    }
}

/// The time left, the arrival count, or a red warning while an alert is on.
private struct TripActivityCompactTrailing: View {
    let state: TripActivityAttributes.ContentState

    var body: some View {
        Group {
            if state.alert != nil {
                // The car's name on the leading side already says who the alert is about.
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(Color(.tripAlertRed))
                    .accessibilityHidden(true)
            } else if let arrival = state.arrival {
                Text(arrival.countText)
                    .foregroundStyle(Color(.brandYellow))
            } else {
                Text(state.shortTimeLeftText ?? "")
            }
        }
        .font(.system(.footnote, design: .rounded, weight: .black))
    }
}

private extension TripActivityAttributes.ContentState {
    static let preview = TripActivityAttributes.ContentState(
        stage: .driving,
        turn: TripActivityAttributes.Turn(
            symbolName: "arrow.turn.up.right", distanceText: "300 m", instruction: "Turn right onto Jl. Raya Puncak"
        ),
        timeLeftText: "1 hr, 20 min",
        shortTimeLeftText: "1:20",
        detailText: "64 km · Arrive 11:01",
        nextStopText: "Next stop: Rest area KM 57",
        groupText: "Following Budi",
        isGroupWarning: false,
        alert: nil,
        arrival: nil,
        robots: [
            PreviewRobot(.green, at: 0.1),
            PreviewRobot(.pink, at: 0.22),
            PreviewRobot(.blue, at: 0.36, isMe: true),
            PreviewRobot(.yellow, at: 0.5, isLeader: true)
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
        isLeader: Bool = false
    ) -> TripActivityAttributes.Robot {
        TripActivityAttributes.Robot(
            id: UUID(), color: color, progress: progress, isMe: isMe, isLeader: isLeader, isAlerting: false
        )
    }

    static var previewAlert: Self {
        var state = preview
        state.alert = TripActivityAttributes.Alert(text: "Citra has gone out of route", color: .pink, carName: "Citra")
        state.robots[1].isAlerting = true
        return state
    }

    static var previewArrived: Self {
        var state = preview
        state.stage = .arrived
        state.turn = nil
        state.arrival = TripActivityAttributes.Arrival(title: "You have arrived", countText: "3/4")
        return state
    }
}

#Preview("Lock Screen", as: .content, using: TripActivityAttributes(title: "To Puncak")) {
    TripLiveActivityWidget()
} contentStates: {
    TripActivityAttributes.ContentState.preview
    TripActivityAttributes.ContentState.previewAlert
    TripActivityAttributes.ContentState.previewArrived
}

#Preview("Island expanded", as: .dynamicIsland(.expanded), using: TripActivityAttributes(title: "To Puncak")) {
    TripLiveActivityWidget()
} contentStates: {
    TripActivityAttributes.ContentState.preview
    TripActivityAttributes.ContentState.previewAlert
}

#Preview("Island compact", as: .dynamicIsland(.compact), using: TripActivityAttributes(title: "To Puncak")) {
    TripLiveActivityWidget()
} contentStates: {
    TripActivityAttributes.ContentState.preview
    TripActivityAttributes.ContentState.previewAlert
    TripActivityAttributes.ContentState.previewArrived
}

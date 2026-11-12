//
//  TripActivityLockScreenView.swift
//  LezgoWidgets
//
//  Created by Nathan Sudiara on 12/11/26.
//

import SwiftUI
import WidgetKit

/// The trip on the Lock Screen and the CarPlay dashboard: your mascot, the next turn, the convoy road and the time.
struct TripActivityLockScreenView: View {
    let title: String
    let state: TripActivityAttributes.ContentState

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center, spacing: 10) {
                TripActivityHeadline(title: title, state: state)
                TripActivityMuteButton(state: state, showsLabel: false)
            }
            TripActivityConvoyRoad(robots: state.robots, robotSize: 26)
            TripActivityFooter(state: state)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .foregroundStyle(.white)
        .fontDesign(.rounded)
    }
}

/// The mascot sticker and what matters most now: the alert, the arrival or the next turn.
private struct TripActivityHeadline: View {
    let title: String
    let state: TripActivityAttributes.ContentState

    var body: some View {
        HStack(spacing: 8) {
            Image(sticker)
                .resizable()
                .scaledToFit()
                .frame(width: 54, height: 54)
                .rotationEffect(.degrees(-8))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 1) {
                Text(title.uppercased())
                    .font(.system(.caption2, design: .rounded, weight: .black))
                    .foregroundStyle(Color(.brandYellow))
                    .lineLimit(1)
                TripActivityHeadlineText(state: state)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
    }

    private var sticker: ImageResource {
        if let alert = state.alert { return alert.color.sticker }
        if state.stage == .arrived { return .mascotCheer }
        return state.myColor.sticker
    }
}

/// The big line under the title.
private struct TripActivityHeadlineText: View {
    let state: TripActivityAttributes.ContentState

    var body: some View {
        if let arrival = state.arrival {
            Text(arrival.title)
                .font(.system(.title3, design: .rounded, weight: .black))
            Text(arrival.countText)
                .font(.system(.subheadline, design: .rounded, weight: .heavy))
                .foregroundStyle(Color(.brandYellow))
        } else if let alert = state.alert {
            Text(alert.text)
                .font(.system(.headline, design: .rounded, weight: .black))
                .foregroundStyle(Color(.tripAlertRed))
                .lineLimit(2)
            TurnLine(state: state, isSmall: true)
        } else {
            TurnLine(state: state, isSmall: false)
        }
    }
}

/// "↱ 300 m  Turn right onto Jl. Raya Puncak", or "Finding the route…" while there is no turn.
private struct TurnLine: View {
    let state: TripActivityAttributes.ContentState
    let isSmall: Bool

    var body: some View {
        if let turn = state.turn {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Label(turn.distanceText, systemImage: turn.symbolName)
                    .font(.system(isSmall ? .subheadline : .title2, design: .rounded, weight: .black))
                    .foregroundStyle(Color(.brandYellow))
                Text(turn.instruction)
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(.white.opacity(0.8))
                    .lineLimit(1)
            }
        } else if state.stage != .arrived {
            Text("…")
                .font(.system(.title3, design: .rounded, weight: .black))
                .foregroundStyle(.white.opacity(0.6))
        }
    }
}

/// The time left and arrival on the left, the group on the right, then the next stop.
private struct TripActivityFooter: View {
    let state: TripActivityAttributes.ContentState

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(alignment: .firstTextBaseline) {
                if let timeLeft = state.timeLeftText {
                    Text(timeLeft)
                        .font(.system(.subheadline, design: .rounded, weight: .black))
                }
                if let detail = state.detailText {
                    Text(detail)
                        .font(.system(.caption, design: .rounded, weight: .bold))
                        .foregroundStyle(.white.opacity(0.6))
                }
                Spacer(minLength: 4)
                Text(state.groupText)
                    .font(.system(.caption, design: .rounded, weight: .heavy))
                    .foregroundStyle(state.isGroupWarning ? Color(.tripAlertRed) : Color(.brandYellow))
            }
            .lineLimit(1)
            if let nextStop = state.nextStopText, state.stage != .arrived {
                Text(nextStop)
                    .font(.system(.caption2, design: .rounded, weight: .bold))
                    .foregroundStyle(.white.opacity(0.7))
                    .lineLimit(1)
            }
        }
    }
}

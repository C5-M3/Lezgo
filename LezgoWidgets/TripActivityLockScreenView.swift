//
//  TripActivityLockScreenView.swift
//  LezgoWidgets
//
//  Created by Nathan Sudiara on 12/11/26.
//

import SwiftUI
import WidgetKit

/// The trip on the Lock Screen and the CarPlay dashboard, within iOS's 160 pt: the mascot with the next stop and the
/// turn, the convoy road with every stop, then the time and the group.
struct TripActivityLockScreenView: View {
    let state: TripActivityAttributes.ContentState

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center, spacing: 10) {
                Image(TripActivitySticker.For(state))
                    .resizable()
                    .scaledToFit()
                    .frame(width: 52, height: 52)
                    .rotationEffect(.degrees(state.alert == nil ? -8 : 10))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    TripActivityHeadlineLabel(state: state)
                    TripActivityMainLine(state: state)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityElement(children: .combine)
                TripActivityCorner(state: state)
            }
            TripActivityConvoyRoad(robots: state.robots, stops: state.stops, robotSize: 26)
            TripActivityFooter(state: state)
        }
        .padding(.horizontal, 14)
        .padding(.top, 12)
        .padding(.bottom, 10)
        .foregroundStyle(.white)
        .fontDesign(.rounded)
        .overlay {
            if state.alert != nil {
                ContainerRelativeShape()
                    .strokeBorder(Color(.tripAlertRed), lineWidth: 2)
            }
        }
    }
}

/// The mascot sticker: this car's, the car with the alert, or the cheering one on arrival.
enum TripActivitySticker {
    static func For(_ state: TripActivityAttributes.ContentState) -> ImageResource {
        if let alert = state.alert { return alert.color.sticker }
        if state.arrival != nil { return .mascotCheer }
        return state.myColor.sticker
    }
}

/// "NEXT STOP · REST AREA KM 57", or how far away the car with the alert is.
private struct TripActivityHeadlineLabel: View {
    let state: TripActivityAttributes.ContentState

    var body: some View {
        Text((state.alert?.detail ?? state.headline).uppercased())
            .font(.system(size: 11, weight: .black, design: .rounded))
            .foregroundStyle(state.alert == nil ? Color(.brandYellow) : Color(.tripAlertRed))
            .lineLimit(1)
    }
}

/// The big line: the alert, the arrival, the next turn, or "Rerouting…".
private struct TripActivityMainLine: View {
    let state: TripActivityAttributes.ContentState

    var body: some View {
        if let alert = state.alert {
            Text(alert.text)
                .font(.system(size: 21, weight: .black, design: .rounded))
                .foregroundStyle(Color(.tripAlertRed))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        } else if let arrival = state.arrival {
            Text(arrival.title)
                .font(.system(size: 22, weight: .black, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        } else if let turn = state.turn {
            HStack(spacing: 7) {
                Image(systemName: turn.symbolName)
                    .font(.system(size: 17, weight: .black))
                    .foregroundStyle(Color(.tripCard))
                    .frame(width: 30, height: 30)
                    .background(Color(.brandYellow), in: .rect(cornerRadius: 9))
                    .accessibilityHidden(true)
                Text(turn.distanceText)
                    .font(.system(size: 24, weight: .black, design: .rounded))
                    .fixedSize()
                Text(turn.instruction)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.72))
                    .lineLimit(1)
            }
        } else {
            Text(state.statusText ?? state.timeLeftText ?? "")
                .font(.system(size: 20, weight: .black, design: .rounded))
                .foregroundStyle(.white.opacity(0.7))
        }
    }
}

/// The top-right corner: the arrival count once arrived, otherwise Mute.
private struct TripActivityCorner: View {
    let state: TripActivityAttributes.ContentState

    var body: some View {
        if let arrival = state.arrival {
            Text(arrival.countText)
                .font(.system(size: 17, weight: .black, design: .rounded))
                .foregroundStyle(Color(.tripCard))
                .padding(.horizontal, 10)
                .frame(height: 32)
                .background(Color(.brandYellow), in: .capsule)
        } else {
            TripActivityMuteButton(state: state, showsLabel: false)
                .padding(-5)
        }
    }
}

/// The bottom line: time, distance and arrival, and the group; the turn while an alert takes the main line.
private struct TripActivityFooter: View {
    let state: TripActivityAttributes.ContentState

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 5) {
            if let arrival = state.arrival {
                Text(arrival.detail ?? "")
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white.opacity(0.72))
                Spacer(minLength: 4)
            } else {
                if let turn = state.turn, state.alert != nil {
                    Label(turn.distanceText, systemImage: turn.symbolName)
                        .font(.system(size: 14, weight: .black, design: .rounded))
                        .foregroundStyle(Color(.brandYellow))
                } else if let timeLeft = state.timeLeftText {
                    Text(timeLeft)
                        .font(.system(size: 15, weight: .black, design: .rounded))
                }
                Text(state.detailText ?? "")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.6))
                Spacer(minLength: 4)
                Text(state.groupText)
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .foregroundStyle(state.isGroupWarning ? Color(.tripAlertRed) : Color(.brandYellow))
            }
        }
        .lineLimit(1)
    }
}

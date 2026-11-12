//
//  TripActivityLockScreenView.swift
//  LezgoWidgets
//
//  Created by Nathan Sudiara on 12/11/26.
//

import SwiftUI
import WidgetKit

/// The trip on the Lock Screen and on a Mac: where the group is going next, how long it takes, and every car on the
/// way. CarPlay and Apple Watch get the smaller `TripActivitySmallView`.
struct TripActivityLockScreenView: View {
    let state: TripActivityAttributes.ContentState

    var body: some View {
        VStack(spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(state.title)
                    .font(.system(size: 19, weight: .semibold))
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                TripActivityTime(state: state, size: 30)
            }
            TripActivityLegRoad(state: state, robotSize: 36)
            TripActivityLegLabels(state: state)
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 14)
        .foregroundStyle(.white)
    }
}

/// "50 min" to the next stop, "3/4" in yellow once arrived, or a dash before the time is known.
struct TripActivityTime: View {
    let state: TripActivityAttributes.ContentState
    let size: CGFloat
    var isShort = false

    var body: some View {
        if let count = state.countText {
            Text(count)
                .font(.system(size: size, weight: .bold))
                .foregroundStyle(Color(.brandYellow))
        } else {
            Text((isShort ? state.shortTimeText : state.timeText) ?? "–")
                .font(.system(size: size, weight: .bold))
                .contentTransition(.numericText(countsDown: true))
                .fixedSize()
        }
    }
}

/// "Start" or the stop just passed under the ring, "Stop 1 of 2" or "Destination" under the flag.
struct TripActivityLegLabels: View {
    let state: TripActivityAttributes.ContentState

    var body: some View {
        HStack(spacing: 12) {
            Text(state.legStartLabel)
                .lineLimit(1)
            Spacer(minLength: 0)
            Text(state.legEndLabel)
                .fixedSize()
        }
        .font(.footnote.weight(.medium))
        .foregroundStyle(Color(white: 0.56))
    }
}

//
//  TripActivityMuteButton.swift
//  LezgoWidgets
//
//  Created by Nathan Sudiara on 12/11/26.
//

import AppIntents
import SwiftUI

/// Mute / Unmute, the same switch as the trip map's button. It runs in the app through `ToggleTripMuteIntent`.
struct TripActivityMuteButton: View {
    let state: TripActivityAttributes.ContentState
    /// The Lock Screen shows a round icon to save room; VoiceOver still reads the label.
    var showsLabel = true

    private var symbolName: String {
        state.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill"
    }

    var body: some View {
        Button(intent: ToggleTripMuteIntent()) {
            if showsLabel {
                Label(state.muteLabel, systemImage: symbolName)
                    .labelStyle(.titleAndIcon)
                    .padding(.horizontal, 12)
                    .frame(height: 30)
                    .background(.white.opacity(0.14), in: .capsule)
            } else {
                Label(state.muteLabel, systemImage: symbolName)
                    .labelStyle(.iconOnly)
                    .frame(width: 34, height: 34)
                    .background(.white.opacity(0.14), in: .circle)
                    .frame(width: 44, height: 44)
                    .contentShape(.rect)
            }
        }
        .buttonStyle(.plain)
        .font(.system(.footnote, design: .rounded, weight: .heavy))
        .foregroundStyle(state.isMuted ? Color(.brandYellow) : .white)
    }
}

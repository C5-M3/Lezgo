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
    /// The Lock Screen shows only the icon to save room; VoiceOver still reads the label.
    var showsLabel = true

    var body: some View {
        Button(intent: ToggleTripMuteIntent()) {
            Label(state.muteLabel, systemImage: state.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                .font(.system(.footnote, design: .rounded, weight: .heavy))
                .modifier(MuteLabelVisibility(showsLabel: showsLabel))
                .frame(minWidth: 44, minHeight: 44)
                .padding(.horizontal, showsLabel ? 12 : 0)
                .background(.white.opacity(0.14), in: .capsule)
        }
        .buttonStyle(.plain)
        .foregroundStyle(state.isMuted ? Color(.brandYellow) : .white)
    }
}

/// Hides the word "Mute" but keeps it for VoiceOver.
private struct MuteLabelVisibility: ViewModifier {
    let showsLabel: Bool

    func body(content: Content) -> some View {
        if showsLabel {
            content.labelStyle(.titleAndIcon)
        } else {
            content.labelStyle(.iconOnly)
        }
    }
}

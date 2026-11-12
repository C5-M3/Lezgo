//
//  SiriMuteSnippet.swift
//  Lezgo
//
//  Created by Nathan Sudiara on 12/11/26.
//

import AppIntents
import SwiftUI

/// Siri's card after "Mute Lezgo" or "Unmute Lezgo" (US-08), with a button that flips it back without opening the app.
/// The button has a row of its own, so it never squeezes the text on a narrow card.
struct SiriMuteSnippet: View {
    let isMuted: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                    .font(.title3)
                    .frame(width: 40, height: 40)
                    .background(.fill.tertiary, in: .circle)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 1) {
                    Text(isMuted ? .siriVoiceAlertsOff : .siriVoiceAlertsOn)
                        .font(.headline)
                        .lineLimit(1)
                    Text(isMuted ? .siriVoiceAlertsOffDetail : .siriVoiceAlertsOnDetail)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Spacer(minLength: 0)
            }
            Button(intent: MuteAlertsIntent(muted: isMuted == false)) {
                Label {
                    Text(isMuted ? .tripMapUnmute : .tripMapMute)
                } icon: {
                    Image(systemName: isMuted ? "speaker.wave.2.fill" : "speaker.slash.fill")
                }
                .font(.body.bold())
                .lineLimit(1)
                .foregroundStyle(Color(.tripCard))
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(Color(.brandYellow), in: .capsule)
            }
            .buttonStyle(.plain)
        }
        .padding()
    }
}

#Preview("Muted") {
    SiriMuteSnippet(isMuted: true)
}

#Preview("Unmuted, largest text") {
    SiriMuteSnippet(isMuted: false)
        .dynamicTypeSize(.accessibility2)
}

//
//  SiriMuteSnippet.swift
//  Lezgo
//
//  Created by Nathan Sudiara on 12/11/26.
//

import AppIntents
import SwiftUI

/// Siri's card after "Mute Lezgo" or "Unmute Lezgo" (US-08), with a button that flips it back without opening the app.
struct SiriMuteSnippet: View {
    let isMuted: Bool

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                .font(.title2)
                .frame(width: 52, height: 52)
                .background(.fill.tertiary, in: .circle)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(isMuted ? .siriVoiceAlertsOff : .siriVoiceAlertsOn)
                    .font(.headline)
                Text(isMuted ? .siriVoiceAlertsOffDetail : .siriVoiceAlertsOnDetail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            Button(intent: MuteAlertsIntent(muted: isMuted == false)) {
                Label {
                    Text(isMuted ? .tripMapUnmute : .tripMapMute)
                } icon: {
                    Image(systemName: isMuted ? "speaker.wave.2.fill" : "speaker.slash.fill")
                }
                .font(.body.bold())
                .foregroundStyle(Color(.tripCard))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color(.brandYellow), in: .capsule)
            }
            .buttonStyle(.plain)
        }
    }
}

#Preview("Muted") {
    SiriMuteSnippet(isMuted: true)
        .padding()
}

#Preview("Unmuted") {
    SiriMuteSnippet(isMuted: false)
        .padding()
}

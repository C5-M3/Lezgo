//
//  MuteAlertsIntent.swift
//  Lezgo
//
//  Created by Nathan Sudiara on 12/11/26.
//

import AppIntents
import SwiftUI

/// "Mute Lezgo" / "Unmute Lezgo" (US-08): the same switch as the trip map's Mute button. Its card has a button
/// that flips it back, which runs this intent again without opening the app.
struct MuteAlertsIntent: AppIntent {
    static let title: LocalizedStringResource = "Mute Voice Alerts"
    static let description = IntentDescription("Turns Lezgo's spoken turns and alert sounds off or on.")
    static let supportedModes: IntentModes = .background

    @Parameter(title: "Muted", default: true)
    var muted: Bool

    init() {}

    init(muted: Bool) {
        self.muted = muted
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetIntent {
        guard let tripMap = SiriTripMap.Current()?.tripMap else {
            return .result(dialog: IntentDialog(stringLiteral: TripAnswers.noTrip))
        }
        tripMap.SetMuted(muted)
        return .result(
            dialog: IntentDialog(stringLiteral: TripAnswers.Mute(isMuted: muted)),
            snippetIntent: MuteSnippetIntent()
        )
    }
}

/// Draws the mute card from the switch as it is now, so it is right again after its button is tapped.
struct MuteSnippetIntent: SnippetIntent {
    static let title: LocalizedStringResource = "Voice Alerts"
    static let isDiscoverable = false

    @MainActor
    func perform() async throws -> some IntentResult & ShowsSnippetView {
        let isMuted = SiriTripMap.Current()?.tripMap.sound.isMuted ?? false
        return .result(view: SiriMuteSnippet(isMuted: isMuted))
    }
}

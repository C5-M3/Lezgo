//
//  MuteAlertsIntent.swift
//  Lezgo
//
//  Created by Nathan Sudiara on 12/11/26.
//

import AppIntents
import SwiftUI

/// "Mute Lezgo" / "Unmute Lezgo" (US-08): the same switch as the trip map's Mute button. On iOS 26 its card has a
/// button that flips it back, which runs this intent again without opening the app. Before iOS 26 Siri only says it
/// (ADR 0031).
struct MuteAlertsIntent: AppIntent {
    static let title: LocalizedStringResource = "Mute Voice Alerts"
    static let description = IntentDescription("Turns Lezgo's spoken turns and alert sounds off or on.")

    @Parameter(title: "Muted", default: true)
    var muted: Bool

    init() {}

    init(muted: Bool) {
        self.muted = muted
    }

    /// The signature names only the dialog, the one result every version returns: iOS 18 stops the app when
    /// `perform()` returns a kind of result its signature does not name. Each `#available` branch may hold only one
    /// `return`, so "no trip" is a refusal before the check.
    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let tripMap = SiriTripMap.Current()?.tripMap else { throw SiriRefusal.saying(TripAnswers.noTrip) }
        tripMap.SetMuted(muted)
        let dialog = IntentDialog(stringLiteral: TripAnswers.Mute(isMuted: muted))
        if #available(iOS 26.0, *) {
            return .result(dialog: dialog, snippetIntent: MuteSnippetIntent())
        } else {
            return .result(dialog: dialog)
        }
    }
}

/// Draws the mute card from the switch as it is now, so it is right again after its button is tapped. Interactive
/// snippets start in iOS 26.
@available(iOS 26.0, *)
struct MuteSnippetIntent: SnippetIntent {
    static let title: LocalizedStringResource = "Voice Alerts"
    static let isDiscoverable = false

    @MainActor
    func perform() async throws -> some IntentResult & ShowsSnippetView {
        let isMuted = SiriTripMap.Current()?.tripMap.sound.isMuted ?? false
        return .result(view: SiriMuteSnippet(isMuted: isMuted))
    }
}

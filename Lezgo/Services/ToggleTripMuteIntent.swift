//
//  ToggleTripMuteIntent.swift
//  Lezgo
//
//  Created by Nathan Sudiara on 12/11/26.
//

import AppIntents

/// The Mute / Unmute button on the trip's Live Activity (ADR 0027). It runs in the app, so it toggles the same mute
/// as the trip map's button.
///
/// The widget extension compiles this file too, to draw the button, but cannot see the trip map; the app hands over
/// what to do through `toggle` when it launches.
struct ToggleTripMuteIntent: LiveActivityIntent {
    static let title = LocalizedStringResource("tripActivityToggleMute")
    static let isDiscoverable = false

    /// Set by the app at launch; `nil` in the widget extension, where the intent never runs.
    @MainActor static var toggle: (() -> Void)?

    func perform() async throws -> some IntentResult {
        await MainActor.run { Self.toggle?() }
        return .result()
    }
}

//
//  LezgoShortcuts.swift
//  Lezgo
//
//  Created by Nathan Sudiara on 12/11/26.
//

import AppIntents

/// The Siri phrases of US-08 (ADR 0030). They work as soon as the app is installed, and show in the Shortcuts app and
/// Spotlight. Every phrase names the app, as Apple requires.
struct LezgoShortcuts: AppShortcutsProvider {
    static let shortcutTileColor: ShortcutTileColor = .yellow

    /// Tells Siri the cars' names again, so "Where's Budi in Lezgo" knows them. The trip map calls it when the cars
    /// change, and when it closes.
    static func RefreshCarNames() {
        updateAppShortcutParameters()
    }

    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: WhereIsLeaderIntent(),
            phrases: [
                "Where's the leader in \(.applicationName)",
                "Where is the leader in \(.applicationName)",
                "Find the leader in \(.applicationName)"
            ],
            shortTitle: "Where's the Leader",
            systemImageName: "crown.fill"
        )
        AppShortcut(
            intent: WhereIsCarIntent(),
            phrases: [
                "Where's \(\.$car) in \(.applicationName)",
                "Where is \(\.$car) in \(.applicationName)",
                "Find a car in \(.applicationName)"
            ],
            shortTitle: "Where's a Car",
            systemImageName: "car.fill"
        )
        AppShortcut(
            intent: EveryoneWithMeIntent(),
            phrases: [
                "Is everyone with me in \(.applicationName)",
                "Where's my group in \(.applicationName)",
                "Check my group in \(.applicationName)"
            ],
            shortTitle: "Is Everyone With Me",
            systemImageName: "person.3.fill"
        )
        AppShortcut(
            intent: TimeLeftIntent(),
            phrases: [
                "How long left in \(.applicationName)",
                "How far is it in \(.applicationName)",
                "When do we arrive in \(.applicationName)"
            ],
            shortTitle: "How Long Left",
            systemImageName: "clock.fill"
        )
        AppShortcut(
            intent: MuteAlertsIntent(muted: true),
            phrases: ["Mute \(.applicationName)", "Mute \(.applicationName) alerts"],
            shortTitle: "Mute",
            systemImageName: "speaker.slash.fill"
        )
        AppShortcut(
            intent: MuteAlertsIntent(muted: false),
            phrases: ["Unmute \(.applicationName)", "Unmute \(.applicationName) alerts"],
            shortTitle: "Unmute",
            systemImageName: "speaker.wave.2.fill"
        )
        AppShortcut(
            intent: ArrivedIntent(),
            phrases: [
                "I've arrived in \(.applicationName)",
                "I arrived in \(.applicationName)",
                "We're here in \(.applicationName)"
            ],
            shortTitle: "I've Arrived",
            systemImageName: "flag.checkered"
        )
    }
}

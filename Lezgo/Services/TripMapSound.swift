//
//  TripMapSound.swift
//  Lezgo
//
//  Created by Nathan Sudiara on 09/11/26.
//

import Foundation
import Observation

/// What the trip map says out loud, and the mute button (`specs/UserStories.md` → US-06, "Sound", ADR 0024).
///
/// `TripMapAnnouncer` decides what to say and a `NavigationSpeaker` plays it. Without a speaker (previews, the
/// simulated drive) the map stays silent. The mute choice is a preference, not a secret, so it lives in
/// `UserDefaults` and the next trip starts muted too.
@Observable
final class TripMapSound {
    /// `true` after "Mute": nothing is spoken and no chime plays.
    private(set) var isMuted: Bool
    private var announcer = TripMapAnnouncer()
    @ObservationIgnored private let speaker: (any NavigationSpeaker)?
    @ObservationIgnored private let preferences: UserDefaults

    static let mutedKey = "tripMapSoundMuted"

    init(speaker: (any NavigationSpeaker)? = nil, preferences: UserDefaults = .standard) {
        self.speaker = speaker
        self.preferences = preferences
        isMuted = preferences.bool(forKey: Self.mutedKey)
    }

    /// "Mute" or "Unmute". Muting stops what is being said at once.
    func ToggleMute() {
        isMuted.toggle()
        preferences.set(isMuted, forKey: Self.mutedKey)
        if isMuted { speaker?.Stop() }
    }

    /// Mute or unmute by Siri (US-08): asking for the state it is already in changes nothing.
    func SetMuted(_ muted: Bool) {
        guard muted != isMuted else { return }
        ToggleMute()
    }

    /// Says what is new on the map. The announcer keeps track while muted too, so unmuting does not replay
    /// everything that happened meanwhile.
    func Update(guidance: TripMapGuidance?, banner: TripMapAlerts.Banner?, notice: TripMapNotice?) {
        let announcements = announcer.Update(guidance: guidance, banner: banner, notice: notice)
        guard isMuted == false, let speaker else { return }
        announcements.forEach(speaker.Announce)
    }

    /// The map closed: nothing more is said.
    func Stop() {
        speaker?.Stop()
    }
}

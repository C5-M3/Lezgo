//
//  NavigationVoiceTests.swift
//  LezgoTests
//
//  Created by Nathan Sudiara on 09/11/26.
//

import AVFoundation
import Foundation
import Testing
@testable import Lezgo

/// Which voice speaks the trip map, and in which language (ADR 0024). The app's text is English, so an Indonesian
/// phone still needs an English voice, or "Turn right" is read with Indonesian pronunciation.
struct NavigationVoiceTests {
    private static let indonesia = Locale(identifier: "id_ID")

    private func Voice(
        _ identifier: String,
        _ language: String,
        _ quality: AVSpeechSynthesisVoiceQuality
    ) -> NavigationVoice {
        NavigationVoice(identifier: identifier, language: language, quality: quality)
    }

    @Test func APremiumVoiceBeatsTheCompactOne() {
        let voices = [
            Voice("compact", "en-US", .default),
            Voice("premium", "en-US", .premium),
            Voice("enhanced", "en-US", .enhanced)
        ]

        let best = NavigationVoice.Best(among: voices, for: Locale(identifier: "en_US"))

        #expect(best?.identifier == "premium")
    }

    @Test func AVoiceInAnotherLanguageIsNeverPicked() {
        let voices = [Voice("indonesian", "id-ID", .premium), Voice("english", "en-US", .default)]

        let best = NavigationVoice.Best(among: voices, for: Locale(identifier: "en_ID"))

        #expect(best?.identifier == "english")
    }

    @Test func QualityMattersMoreThanTheAccent() {
        let voices = [Voice("american", "en-US", .default), Voice("british", "en-GB", .enhanced)]

        let best = NavigationVoice.Best(among: voices, for: Locale(identifier: "en_US"))

        #expect(best?.identifier == "british")
    }

    @Test func TheSameQualityPrefersThePhonesRegion() {
        let voices = [
            Voice("american", "en-US", .enhanced),
            Voice("australian", "en-AU", .enhanced),
            Voice("british", "en-GB", .enhanced)
        ]

        let best = NavigationVoice.Best(among: voices, for: Locale(identifier: "en_GB"))

        #expect(best?.identifier == "british")
    }

    @Test func NoVoiceInTheLanguageGivesNone() {
        let voices = [Voice("indonesian", "id-ID", .premium)]

        let best = NavigationVoice.Best(among: voices, for: Locale(identifier: "en_ID"))

        #expect(best == nil)
    }

    @Test func AnIndonesianPhoneSpeaksTheAppsEnglishWithItsRegion() {
        let locale = NavigationVoice.SpeechLocale(appLanguage: "en", phone: Self.indonesia)

        #expect(locale.language.languageCode == .english)
        #expect(locale.region == .indonesia)
    }

    @Test func TheDistanceIsReadInTheAppsLanguage() {
        let locale = NavigationVoice.SpeechLocale(appLanguage: "en", phone: Self.indonesia)

        let text = TripMapAnnouncer.Announcement.turn(instruction: "Turn right", meters: 200).SpokenText(locale: locale)

        #expect(text.hasPrefix("In 200 met"))
    }
}

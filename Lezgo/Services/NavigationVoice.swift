//
//  NavigationVoice.swift
//  Lezgo
//
//  Created by Nathan Sudiara on 09/11/26.
//

import AVFoundation

/// A voice the phone can speak with, and how the trip map picks one (ADR 0024).
///
/// `AVSpeechSynthesisVoice(language:)` always returns the compact voice, which sounds robotic. The phone often has
/// an Enhanced or Premium voice too (Settings > Accessibility > Spoken Content > Voices), so the trip map picks the
/// best one in the app's language. Siri's own voices, which Apple Maps uses, are not open to other apps.
struct NavigationVoice: Hashable {
    let identifier: String
    /// A BCP 47 code, for example "en-US".
    let language: String
    let quality: AVSpeechSynthesisVoiceQuality

    /// Every voice installed on this phone.
    static func Installed() -> [NavigationVoice] {
        AVSpeechSynthesisVoice.speechVoices().map {
            NavigationVoice(identifier: $0.identifier, language: $0.language, quality: $0.quality)
        }
    }

    /// The best voice for `locale`: the highest quality in its language, then one from its region. A voice in another
    /// language is never picked, even a better one, because it would mispronounce every word.
    static func Best(among voices: [NavigationVoice], for locale: Locale) -> NavigationVoice? {
        voices
            .filter { Locale.Language(identifier: $0.language).languageCode == locale.language.languageCode }
            .max { Rank($0, for: locale) < Rank($1, for: locale) }
    }

    /// The language the trip map speaks: the app's own (its text is English even on an Indonesian phone), with the
    /// phone's region, so distances use the phone's units and spelling.
    static func SpeechLocale(
        appLanguage: String = Bundle.main.preferredLocalizations.first ?? "en",
        phone: Locale = .current
    ) -> Locale {
        Locale(languageCode: Locale.LanguageCode(appLanguage), languageRegion: phone.region)
    }

    private static func Rank(_ voice: NavigationVoice, for locale: Locale) -> (Int, Int) {
        let sameRegion = Locale(identifier: voice.language).region == locale.region
        return (voice.quality.rawValue, sameRegion ? 1 : 0)
    }
}

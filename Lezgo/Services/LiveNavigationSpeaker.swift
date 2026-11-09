//
//  LiveNavigationSpeaker.swift
//  Lezgo
//
//  Created by Nathan Sudiara on 09/11/26.
//

import AVFoundation

/// Speaks turns and alerts with `AVSpeechSynthesizer`, and plays `AlertChime.caf` before an alert (ADR 0024).
///
/// The audio session is active only while something plays. It lowers other audio (music, a podcast) meanwhile and
/// lets it come back after. It plays with the screen locked (the `audio` background mode) and through CarPlay.
final class LiveNavigationSpeaker: NSObject, NavigationSpeaker {
    private let synthesizer = AVSpeechSynthesizer()
    private let chime: AVAudioPlayer?
    private let session = AVAudioSession.sharedInstance()

    /// How long the chime plays before the alert's text is spoken.
    private static let chimeSeconds = 0.5

    override init() {
        chime = Bundle.main.url(forResource: "AlertChime", withExtension: "caf")
            .flatMap { try? AVAudioPlayer(contentsOf: $0) }
        super.init()
        chime?.prepareToPlay()
        synthesizer.usesApplicationAudioSession = true
        synthesizer.delegate = self
    }

    func Announce(_ announcement: TripMapAnnouncer.Announcement) {
        // Sound adds to what is on the screen; it never replaces it. Without an audio session (a phone call has
        // it), the banner and turn card still show everything, so this announcement is simply not heard.
        guard ActivateSession() else { return }
        let utterance = AVSpeechUtterance(string: announcement.SpokenText())
        utterance.voice = AVSpeechSynthesisVoice(language: AVSpeechSynthesisVoice.currentLanguageCode())
        // Uses the person's own speech rate and voice from Settings > Accessibility > Spoken Content.
        utterance.prefersAssistiveTechnologySettings = true
        if announcement.playsChime, let chime {
            chime.currentTime = 0
            chime.play()
            utterance.preUtteranceDelay = Self.chimeSeconds
        }
        synthesizer.speak(utterance)
    }

    func Stop() {
        synthesizer.stopSpeaking(at: .immediate)
        chime?.stop()
        DeactivateSession()
    }

    /// Lowers other audio while the app speaks, and interrupts a podcast instead of talking over it.
    private func ActivateSession() -> Bool {
        do {
            try session.setCategory(
                .playback,
                mode: .voicePrompt,
                options: [.duckOthers, .interruptSpokenAudioAndMixWithOthers]
            )
            try session.setActive(true)
            return true
        } catch {
            return false
        }
    }

    /// Gives the volume back to other audio once nothing is left to say.
    private func DeactivateSession() {
        guard synthesizer.isSpeaking == false else { return }
        try? session.setActive(false, options: .notifyOthersOnDeactivation)
    }
}

extension LiveNavigationSpeaker: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in self.DeactivateSession() }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in self.DeactivateSession() }
    }
}

//
//  InfoPlistTests.swift
//  LezgoTests
//
//  Created by Nathan Sudiara on 09/11/26.
//

import Foundation
import Testing

/// Checks keys in the built app's Info.plist that App Store Connect reads.
struct InfoPlistTests {
    /// Lezgo only uses the encryption in Apple's operating system (HTTPS, CloudKit). Declaring it here lets
    /// every build reach TestFlight without answering the export compliance question by hand.
    @Test func DeclaresNoNonExemptEncryption() throws {
        let value = Bundle.main.object(forInfoDictionaryKey: "ITSAppUsesNonExemptEncryption")
        #expect(try #require(value as? Bool) == false)
    }

    /// Voice guidance keeps speaking with the screen locked, as navigation apps do (ADR 0024).
    @Test func PlaysAudioInTheBackground() throws {
        let modes = Bundle.main.object(forInfoDictionaryKey: "UIBackgroundModes") as? [String]
        #expect(try #require(modes).contains("audio"))
    }
}

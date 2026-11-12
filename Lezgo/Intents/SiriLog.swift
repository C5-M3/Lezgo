//
//  SiriLog.swift
//  Lezgo
//
//  Created by Nathan Sudiara on 13/11/26.
//

import Foundation
import os

/// What the Siri intents did, for the device log (US-08). Siri on a real phone only says "Done", so this is the way
/// to see whether an intent ran and how it ended: filter Console on the category "Siri".
enum SiriLog {
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Lezgo", category: "Siri")

    /// One line in the device log. Only room codes and steps are written, never names or places.
    static func Note(_ message: String) {
        logger.info("\(message, privacy: .public)")
    }
}

//
//  TimeLeftIntent.swift
//  Lezgo
//
//  Created by Nathan Sudiara on 12/11/26.
//

import AppIntents
import SwiftUI

/// "How long left in Lezgo" (US-08): the time and distance to the destination, and the next checkpoint.
struct TimeLeftIntent: AppIntent {
    static let title: LocalizedStringResource = "How Long Left"
    static let description = IntentDescription("Says the time and distance left to the destination.")
    static let supportedModes: IntentModes = .background

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        guard let answers = SiriTripMap.Current()?.answers else {
            return .result(dialog: IntentDialog(stringLiteral: TripAnswers.noTrip), view: nil as SiriTimeLeftSnippet?)
        }
        return .result(dialog: IntentDialog(stringLiteral: answers.TimeLeft()), view: SiriSnippets.TimeLeft(answers))
    }
}

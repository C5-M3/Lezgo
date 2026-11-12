//
//  EveryoneWithMeIntent.swift
//  Lezgo
//
//  Created by Nathan Sudiara on 12/11/26.
//

import AppIntents
import SwiftUI

/// "Is everyone with me in Lezgo" (US-08): which cars are with the group, and why the others are not.
struct EveryoneWithMeIntent: AppIntent {
    static let title: LocalizedStringResource = "Is Everyone With Me"
    static let description = IntentDescription("Says which cars are with the group, and which are not.")
    static let supportedModes: IntentModes = .background

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        guard let trip = SiriTripMap.Current() else {
            return .result(dialog: IntentDialog(stringLiteral: TripAnswers.noTrip), view: nil as SiriGroupSnippet?)
        }
        let answers = trip.answers
        let card = answers.state.participants.count > 1 ? SiriSnippets.Group(answers, on: trip.tripMap) : nil
        return .result(dialog: IntentDialog(stringLiteral: answers.EveryoneWithMe()), view: card)
    }
}

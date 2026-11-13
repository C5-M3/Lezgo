//
//  ArrivedIntent.swift
//  Lezgo
//
//  Created by Nathan Sudiara on 12/11/26.
//

import AppIntents
import SwiftUI

/// "I've arrived in Lezgo" (US-08): the "I've Arrived" button by voice, with the same 1 km rule, after Siri asks.
struct ArrivedIntent: AppIntent {
    static let title: LocalizedStringResource = "I've Arrived"
    static let description = IntentDescription("Tells your group you've arrived near the destination.")

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        guard let trip = SiriTripMap.Current() else {
            return .result(dialog: IntentDialog(stringLiteral: TripAnswers.noTrip), view: nil as SiriArrivedSnippet?)
        }
        let tripMap = trip.tripMap
        switch trip.answers.ArrivalCheck() {
        case .refuse(let sentence):
            return .result(dialog: IntentDialog(stringLiteral: sentence), view: nil as SiriArrivedSnippet?)
        case .ask(let confirmation):
            try await requestConfirmation(
                actionName: .continue,
                dialog: IntentDialog(stringLiteral: TripAnswers.ArrivalQuestion(confirmation))
            ) {
                SiriArrivalSnippet(confirmation: confirmation)
            }
            let sentence = await tripMap.ArriveFromSiri(confirmation)
            let card = tripMap.SiriAnswers().map { SiriSnippets.Arrived($0, on: tripMap) }
            return .result(dialog: IntentDialog(stringLiteral: sentence), view: card)
        }
    }
}

//
//  WhereIsCarIntent.swift
//  Lezgo
//
//  Created by Nathan Sudiara on 12/11/26.
//

import AppIntents
import SwiftUI

/// "Where's Budi in Lezgo" (US-08): how far a car of the trip is, and on which street.
struct WhereIsCarIntent: AppIntent {
    static let title: LocalizedStringResource = "Where's a Car"
    static let description = IntentDescription("Says how far a car of your trip is and on which street.")
    static let supportedModes: IntentModes = .background

    @Parameter(title: "Car", requestValueDialog: "Which car?")
    var car: TripCarEntity

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        guard let trip = SiriTripMap.Current(), let found = await SiriSnippets.Car(car.id, on: trip.tripMap) else {
            return .result(dialog: IntentDialog(stringLiteral: TripAnswers.noTrip), view: nil as SiriCarSnippet?)
        }
        return .result(dialog: IntentDialog(stringLiteral: found.answers.WhereIs(carID: car.id)), view: found.card)
    }
}

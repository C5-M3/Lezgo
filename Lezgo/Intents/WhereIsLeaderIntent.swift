//
//  WhereIsLeaderIntent.swift
//  Lezgo
//
//  Created by Nathan Sudiara on 12/11/26.
//

import AppIntents
import SwiftUI

/// "Where's the leader in Lezgo" (US-08): how far the leader's car is, and on which street.
struct WhereIsLeaderIntent: AppIntent {
    static let title: LocalizedStringResource = "Where's the Leader"
    static let description = IntentDescription("Says how far the leader's car is and on which street.")

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        guard let trip = SiriTripMap.Current(), let leader = trip.answers.state.leader,
              leader.id != trip.answers.myParticipantID else {
            let sentence = SiriTripMap.Current()?.answers.WhereIsLeader() ?? TripAnswers.noTrip
            return .result(dialog: IntentDialog(stringLiteral: sentence), view: nil as SiriCarSnippet?)
        }
        guard let found = await SiriSnippets.Car(leader.id, on: trip.tripMap) else {
            return .result(dialog: IntentDialog(stringLiteral: TripAnswers.noTrip), view: nil as SiriCarSnippet?)
        }
        return .result(dialog: IntentDialog(stringLiteral: found.answers.WhereIsLeader()), view: found.card)
    }
}

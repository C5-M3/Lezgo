//
//  CreateTripIntent.swift
//  Lezgo
//
//  Created by Nathan Sudiara on 12/11/26.
//

import AppIntents
import Foundation

/// "Create a trip in Lezgo" (US-08): asks "Where to?" and opens Set Route searching for that place. Siri never picks
/// the place or creates the trip: "Malang" matches several places, and the route needs a look on the map.
struct CreateTripIntent: AppIntent {
    static let title: LocalizedStringResource = "Create a Trip"
    static let description = IntentDescription("Opens Lezgo to plan a trip, searching for the place you say.")
    /// Checks in the background, so Siri keeps the conversation, then brings the app to the front for Set Route.
    static let supportedModes: IntentModes = [.background, .foreground(.dynamic)]

    @Parameter(title: "Destination", requestValueDialog: "Where to?")
    var destination: String

    init() {}

    init(destination: String) {
        self.destination = destination
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard SiriTripMap.HasTripOnThisPhone() == false else { throw SiriRefusal.alreadyInTrip }
        guard let link = PlanLink.Make(destination: destination),
              let place = PlanLink.Destination(from: link) else {
            throw $destination.needsValueError(IntentDialog(stringLiteral: String(localized: .siriWhereToAgain)))
        }
        // Siri cannot open the app's own `lezgo://` links, so Home takes it inside the app.
        SiriHandoff.shared.Open(link)
        await JoinTripIntent.OpenApp(from: self)
        return .result(dialog: IntentDialog(stringLiteral: String(localized: .siriPlanningTrip(place))))
    }
}

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
    /// The app comes to the front before `perform` runs, so Set Route opens when Siri finishes.
    static let supportedModes: IntentModes = .foreground(.immediate)

    @Parameter(title: "Destination", requestValueDialog: "Where to?")
    var destination: String

    init() {}

    init(destination: String) {
        self.destination = destination
    }

    /// What Siri says instead of opening Lezgo.
    enum Refusal: Error, CustomLocalizedStringResourceConvertible {
        /// "You're already in a trip. Open Lezgo to continue it."
        case alreadyInTrip

        var localizedStringResource: LocalizedStringResource { .siriAlreadyInTrip }
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard Self.HasTripOnThisPhone() == false else { throw Refusal.alreadyInTrip }
        guard let link = PlanLink.Make(destination: destination),
              let place = PlanLink.Destination(from: link) else {
            throw $destination.needsValueError(IntentDialog(stringLiteral: String(localized: .siriWhereToAgain)))
        }
        // Siri cannot open the app's own `lezgo://` links, so Home takes it inside the app.
        IncomingLinks.shared.Open(link)
        return .result(dialog: IntentDialog(stringLiteral: String(localized: .siriPlanningTrip(place))))
    }

    /// A trip on the road, in the Trip Room or a draft (US-03): Home keeps it, so Siri says so instead of opening.
    @MainActor
    static func HasTripOnThisPhone(
        activeTripMap: ActiveTripMap = .shared,
        storage: any ActiveTripStorage = UserDefaultsActiveTripStorage()
    ) -> Bool {
        activeTripMap.tripMap != nil || storage.LoadActiveTrip() != nil
    }
}

//
//  SiriRefusal.swift
//  Lezgo
//
//  Created by Nathan Sudiara on 13/11/26.
//

import Foundation

/// What Siri says instead of doing what was asked (US-08). Throwing it ends the intent with this sentence spoken.
enum SiriRefusal: Error, CustomLocalizedStringResourceConvertible {
    /// "You're already in a trip. Open Lezgo to continue it."
    case alreadyInTrip
    /// A sentence the app already shows, such as the join dialog's "No trip found with this code."
    case saying(String)

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .alreadyInTrip: .siriAlreadyInTrip
        case .saying(let sentence): LocalizedStringResource(stringLiteral: sentence)
        }
    }
}

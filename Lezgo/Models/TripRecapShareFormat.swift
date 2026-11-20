//
//  TripRecapShareFormat.swift
//  Lezgo
//

import Foundation

/// A way the trip recap picture can look. The user picks one on the preview screen.
enum TripRecapShareFormat: CaseIterable, Identifiable {
    /// The map with the four details under it.
    case classic
    /// No map: only the route line, with the details around it.
    case routeLine
    /// The map in the middle, with the logo, From and Time on its left and the date, To and Distance on its right.
    case mapCenter
    /// Big letters: "We drove 60 km together." in huge letters with the route line across the number.
    case together
    /// Big letters: the route line big, with Distance, Elapsed and Stops under it.
    case convoy

    var id: Self { self }

    /// The name read aloud by VoiceOver. It is not shown on screen.
    var title: LocalizedStringResource {
        switch self {
        case .classic: "Classic"
        case .routeLine: "Route Line"
        case .mapCenter: "Map Center"
        case .together: "Together"
        case .convoy: "Convoy"
        }
    }

    /// Added to the picture's file name, so two formats of one trip never overwrite each other.
    var fileNameSuffix: String {
        switch self {
        case .classic: ""
        case .routeLine: " Route Line"
        case .mapCenter: " Map Center"
        case .together: " Together"
        case .convoy: " Convoy"
        }
    }
}

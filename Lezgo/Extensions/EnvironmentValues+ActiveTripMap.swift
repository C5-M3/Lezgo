//
//  EnvironmentValues+ActiveTripMap.swift
//  Lezgo
//
//  Created by Nathan Sudiara on 07/11/26.
//

import SwiftUI

extension EnvironmentValues {
    /// Where the trip map tells CarPlay it is open (ADR 0023). The app and its debug screens share one, so a simulated
    /// drive shows on CarPlay too; a preview has no CarPlay screen, so sharing it there is harmless. Tests make their
    /// own `ActiveTripMap`.
    @Entry var activeTripMap = ActiveTripMap.shared
}

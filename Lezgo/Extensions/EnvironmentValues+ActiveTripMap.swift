//
//  EnvironmentValues+ActiveTripMap.swift
//  Lezgo
//
//  Created by Nathan Sudiara on 07/11/26.
//

import SwiftUI

extension EnvironmentValues {
    /// Where the trip map tells CarPlay it is open (ADR 0023). Previews can set their own, so they never show a trip
    /// on a connected CarPlay screen.
    @Entry var activeTripMap = ActiveTripMap.shared
}

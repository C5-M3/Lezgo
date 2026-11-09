//
//  EnvironmentValues+TripService.swift
//  Lezgo
//
//  Created by Nathan Sudiara on 26/10/26.
//

import SwiftUI

extension EnvironmentValues {
    /// The trip service every screen uses (ADR 0017).
    ///
    /// `LezgoApp` sets it once at the root. A view reads it and passes it on to its view model's initializer, for
    /// example when it opens the next screen:
    ///
    /// ```swift
    /// struct HomeView: View {
    ///     @Environment(\.tripService) private var tripService
    ///
    ///     var body: some View {
    ///         NavigationLink("Join trip") {
    ///             JoinTripView(viewModel: JoinTripViewModel(tripService: tripService))
    ///         }
    ///     }
    /// }
    /// ```
    ///
    /// View models never read the environment themselves, so tests pass a service straight into them.
    /// Where nothing sets it, such as a preview, it is `InMemoryTripService.fallback`.
    @Entry var tripService: any TripService = InMemoryTripService.fallback
}

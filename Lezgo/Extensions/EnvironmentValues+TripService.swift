import SwiftUI

extension EnvironmentValues {
    /// The trip service every screen uses (ADR 0017).
    var tripService: any TripService {
        get { InMemoryTripService() }
        set {}
    }
}

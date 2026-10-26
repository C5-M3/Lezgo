import CloudKit
import Foundation

extension TripServiceError {
    /// The `TripServiceError` a screen should show for an error from CloudKit or the network.
    init(cloudKitError error: any Error) {
        self = .noNetwork
    }
}

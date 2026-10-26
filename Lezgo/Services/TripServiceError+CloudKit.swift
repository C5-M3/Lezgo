import CloudKit
import Foundation

extension TripServiceError {
    /// The `TripServiceError` a screen should show for an error from CloudKit or the network.
    ///
    /// Anything unexpected becomes `.noNetwork`, whose message asks the person to try again: on the road, a retry is
    /// almost always the right answer.
    init(cloudKitError error: any Error) {
        switch error {
        case let error as TripServiceError:
            self = error
        case is InvalidTripRecord:
            // The record exists but this build cannot read it, which looks the same as missing to the person.
            self = .notFound
        case let error as CKError:
            self = Self.FromCloudKit(error)
        default:
            self = .noNetwork
        }
    }

    private static func FromCloudKit(_ error: CKError) -> TripServiceError {
        switch error.code {
        case .partialFailure:
            // A batch failed because of one record: report that record's reason.
            guard let first = error.partialErrorsByItemID?.values.first else { return .noNetwork }
            return TripServiceError(cloudKitError: first)
        case .notAuthenticated, .accountTemporarilyUnavailable:
            return .notSignedInToICloud
        case .unknownItem, .zoneNotFound:
            return .notFound
        case .serverRecordChanged:
            return .conflict
        case .permissionFailure:
            return .notAllowed
        default:
            return .noNetwork
        }
    }
}

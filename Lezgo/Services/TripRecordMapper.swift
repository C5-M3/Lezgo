import CloudKit
import Foundation

/// Converts the trip models to and from CloudKit records of the public database (ADR 0014).
///
/// The record types and field names here must match `CloudKit/Schema.ckdb`. Each record's name is the model's
/// UUID. Waypoints, participants and routes point to their trip with a `deleteSelf` reference, so deleting a
/// trip deletes them too.
enum TripRecordMapper {
    static let tripType = "Trip"
    static let waypointType = "Waypoint"
    static let participantType = "Participant"
    static let routeType = "Route"

    static func MakeRecord(_ trip: Trip) -> CKRecord {
        CKRecord(recordType: tripType)
    }

    static func MakeTrip(from record: CKRecord) throws -> Trip {
        throw InvalidTripRecord(recordType: tripType, field: "")
    }

    static func MakeRecord(_ waypoint: Waypoint) -> CKRecord {
        CKRecord(recordType: waypointType)
    }

    static func MakeWaypoint(from record: CKRecord) throws -> Waypoint {
        throw InvalidTripRecord(recordType: waypointType, field: "")
    }

    static func MakeRecord(_ participant: Participant) -> CKRecord {
        CKRecord(recordType: participantType)
    }

    static func MakeParticipant(from record: CKRecord) throws -> Participant {
        throw InvalidTripRecord(recordType: participantType, field: "")
    }

    static func MakeRecord(_ route: Route) -> CKRecord {
        CKRecord(recordType: routeType)
    }

    static func MakeRoute(from record: CKRecord) throws -> Route {
        throw InvalidTripRecord(recordType: routeType, field: "")
    }

    /// The record ID of a model: the default zone of the public database, named after the UUID.
    static func RecordID(_ id: UUID) -> CKRecord.ID {
        CKRecord.ID(recordName: "")
    }
}

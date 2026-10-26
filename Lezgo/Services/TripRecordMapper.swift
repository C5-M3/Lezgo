import CloudKit
import Foundation

/// Converts the trip models to and from CloudKit records of the public database (ADR 0014).
///
/// The record types and field names here must match `CloudKit/Schema.ckdb`. Each record's name is the model's
/// UUID. Waypoints, participants and routes point to their trip with a `deleteSelf` reference, so deleting a
/// trip deletes them too. Reading a record throws `InvalidTripRecord` when a field is missing or unreadable.
enum TripRecordMapper {
    static let tripType = "Trip"
    static let waypointType = "Waypoint"
    static let participantType = "Participant"
    static let routeType = "Route"

    // MARK: Trip

    static func MakeRecord(_ trip: Trip) -> CKRecord {
        let record = CKRecord(recordType: tripType, recordID: RecordID(trip.id))
        Write(trip, into: record)
        return record
    }

    /// Writes the trip's fields into an existing record, for example one fetched for a conditional save.
    static func Write(_ trip: Trip, into record: CKRecord) {
        record["roomCode"] = trip.roomCode
        record["status"] = trip.status.rawValue
        record["leaderParticipantID"] = trip.leaderParticipantID.uuidString
        record["currentWaypointIndex"] = Int64(trip.currentWaypointIndex)
        record["routeVersion"] = Int64(trip.routeVersion)
        record["createdAt"] = trip.createdAt
        record["startedAt"] = trip.startedAt
        record["endedAt"] = trip.endedAt
    }

    static func MakeTrip(from record: CKRecord) throws -> Trip {
        let reader = try RecordReader(record, expectedType: tripType)
        return Trip(
            id: try reader.ID(),
            roomCode: try reader.Value("roomCode"),
            status: try reader.Enum("status"),
            leaderParticipantID: try reader.UUIDString("leaderParticipantID"),
            currentWaypointIndex: try reader.Integer("currentWaypointIndex"),
            routeVersion: try reader.Integer("routeVersion"),
            createdAt: try reader.Value("createdAt"),
            startedAt: reader.OptionalValue("startedAt"),
            endedAt: reader.OptionalValue("endedAt")
        )
    }

    // MARK: Waypoint

    static func MakeRecord(_ waypoint: Waypoint) -> CKRecord {
        let record = CKRecord(recordType: waypointType, recordID: RecordID(waypoint.id))
        record["tripID"] = TripReference(waypoint.tripID)
        record["orderIndex"] = Int64(waypoint.orderIndex)
        record["kind"] = waypoint.kind.rawValue
        record["name"] = waypoint.name
        record["latitude"] = waypoint.coordinate.latitude
        record["longitude"] = waypoint.coordinate.longitude
        return record
    }

    static func MakeWaypoint(from record: CKRecord) throws -> Waypoint {
        let reader = try RecordReader(record, expectedType: waypointType)
        return Waypoint(
            id: try reader.ID(),
            tripID: try reader.TripID(),
            orderIndex: try reader.Integer("orderIndex"),
            kind: try reader.Enum("kind"),
            name: try reader.Value("name"),
            coordinate: Coordinate(latitude: try reader.Value("latitude"), longitude: try reader.Value("longitude"))
        )
    }

    // MARK: Participant

    static func MakeRecord(_ participant: Participant) -> CKRecord {
        let record = CKRecord(recordType: participantType, recordID: RecordID(participant.id))
        Write(participant, into: record)
        return record
    }

    /// Writes the participant's fields into an existing record.
    static func Write(_ participant: Participant, into record: CKRecord) {
        record["tripID"] = TripReference(participant.tripID)
        record["userRecordID"] = participant.userRecordID
        record["displayName"] = participant.displayName
        record["carDescription"] = participant.carDescription
        record["latitude"] = participant.coordinate?.latitude
        record["longitude"] = participant.coordinate?.longitude
        record["speedKmh"] = participant.speedKmh
        record["motionState"] = participant.motionState.rawValue
        record["alert"] = participant.alert.rawValue
        record["lastSeenAt"] = participant.lastSeenAt
    }

    static func MakeParticipant(from record: CKRecord) throws -> Participant {
        let reader = try RecordReader(record, expectedType: participantType)
        let latitude: Double? = reader.OptionalValue("latitude")
        let longitude: Double? = reader.OptionalValue("longitude")
        return Participant(
            id: try reader.ID(),
            tripID: try reader.TripID(),
            userRecordID: try reader.Value("userRecordID"),
            displayName: try reader.Value("displayName"),
            carDescription: reader.OptionalValue("carDescription") ?? "",
            coordinate: latitude.flatMap { latitude in
                longitude.map { Coordinate(latitude: latitude, longitude: $0) }
            },
            speedKmh: reader.OptionalValue("speedKmh") ?? 0,
            motionState: try reader.Enum("motionState"),
            alert: try reader.Enum("alert"),
            lastSeenAt: try reader.Value("lastSeenAt")
        )
    }

    // MARK: Route

    static func MakeRecord(_ route: Route) -> CKRecord {
        let record = CKRecord(recordType: routeType, recordID: RecordID(route.id))
        record["tripID"] = TripReference(route.tripID)
        record["version"] = Int64(route.version)
        record["polyline"] = PolylineBytes(route.polyline)
        return record
    }

    static func MakeRoute(from record: CKRecord) throws -> Route {
        let reader = try RecordReader(record, expectedType: routeType)
        let bytes: Data = reader.OptionalValue("polyline") ?? Data()
        guard let polyline = Polyline(from: bytes) else {
            throw InvalidTripRecord(recordType: routeType, field: "polyline")
        }
        return Route(
            id: try reader.ID(),
            tripID: try reader.TripID(),
            version: try reader.Integer("version"),
            polyline: polyline
        )
    }

    // MARK: IDs and references

    /// The record ID of a model: the default zone of the public database, named after the UUID.
    static func RecordID(_ id: UUID) -> CKRecord.ID {
        CKRecord.ID(recordName: id.uuidString)
    }

    /// A child record's link to its trip. Deleting the trip deletes the child.
    static func TripReference(_ tripID: UUID) -> CKRecord.Reference {
        CKRecord.Reference(recordID: RecordID(tripID), action: .deleteSelf)
    }

    // MARK: Polyline bytes

    /// Each coordinate as two little-endian 64-bit floats (16 bytes), so a 10,000-point route stays far below the
    /// 1 MB record limit, and no precision is lost.
    static func PolylineBytes(_ polyline: [Coordinate]) -> Data {
        var bytes = Data(capacity: polyline.count * 16)
        for coordinate in polyline {
            for value in [coordinate.latitude, coordinate.longitude] {
                withUnsafeBytes(of: value.bitPattern.littleEndian) { bytes.append(contentsOf: $0) }
            }
        }
        return bytes
    }

    /// The coordinates in `bytes`, or `nil` when the length is not a whole number of coordinates.
    static func Polyline(from bytes: Data) -> [Coordinate]? {
        guard bytes.count.isMultiple(of: 16) else { return nil }
        let values = stride(from: 0, to: bytes.count, by: 8).map { offset in
            let bits = bytes[bytes.startIndex + offset ..< bytes.startIndex + offset + 8]
                .enumerated()
                .reduce(UInt64(0)) { $0 | UInt64($1.element) << (8 * UInt64($1.offset)) }
            return Double(bitPattern: bits)
        }
        return stride(from: 0, to: values.count, by: 2).map {
            Coordinate(latitude: values[$0], longitude: values[$0 + 1])
        }
    }
}

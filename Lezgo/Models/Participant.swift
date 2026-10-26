import Foundation

/// One person in a trip, which is also one car and one phone.
///
/// Whether they lead is not stored here: compare with `Trip.leaderParticipantID` through `IsLeader(in:)`.
public struct Participant: Identifiable, Hashable, Codable, Sendable {
    /// How long a phone may go without sending a location before it counts as offline.
    public static let offlineAfter: TimeInterval = 120

    /// The CloudKit record name.
    public let id: UUID
    public var tripID: UUID
    /// The iCloud user. Unique per trip: joining again with the same account returns this record.
    public var userRecordID: String
    public var displayName: String
    public var carDescription: String
    /// `nil` until the phone sends its first location.
    public var coordinate: Coordinate?
    public var speedKmh: Double
    public var motionState: MotionState
    public var alert: FormationAlert
    public var lastSeenAt: Date

    public var name: String {
        get { displayName }
        set { displayName = newValue }
    }

    public var description: String {
        get { carDescription }
        set { carDescription = newValue }
    }

    public var isLeader: Bool

    enum CodingKeys: String, CodingKey {
        case id, tripID, userRecordID, displayName, carDescription
        case coordinate, speedKmh, motionState, alert, lastSeenAt
    }

    public init(
        id: UUID = UUID(),
        tripID: UUID = UUID(),
        userRecordID: String = "",
        displayName: String = "",
        carDescription: String = "",
        name: String? = nil,
        description: String? = nil,
        isLeader: Bool = false,
        coordinate: Coordinate? = nil,
        speedKmh: Double = 0,
        motionState: MotionState = .stopped,
        alert: FormationAlert = .none,
        lastSeenAt: Date = Date()
    ) {
        self.id = id
        self.tripID = tripID
        self.userRecordID = userRecordID
        self.displayName = name ?? displayName
        self.carDescription = description ?? carDescription
        self.isLeader = isLeader
        self.coordinate = coordinate
        self.speedKmh = speedKmh
        self.motionState = motionState
        self.alert = alert
        self.lastSeenAt = lastSeenAt
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        tripID = try container.decode(UUID.self, forKey: .tripID)
        userRecordID = try container.decode(String.self, forKey: .userRecordID)
        displayName = try container.decode(String.self, forKey: .displayName)
        carDescription = try container.decode(String.self, forKey: .carDescription)
        coordinate = try container.decodeIfPresent(Coordinate.self, forKey: .coordinate)
        speedKmh = try container.decode(Double.self, forKey: .speedKmh)
        motionState = try container.decode(MotionState.self, forKey: .motionState)
        alert = try container.decode(FormationAlert.self, forKey: .alert)
        lastSeenAt = try container.decode(Date.self, forKey: .lastSeenAt)
        isLeader = false
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(tripID, forKey: .tripID)
        try container.encode(userRecordID, forKey: .userRecordID)
        try container.encode(displayName, forKey: .displayName)
        try container.encode(carDescription, forKey: .carDescription)
        try container.encodeIfPresent(coordinate, forKey: .coordinate)
        try container.encode(speedKmh, forKey: .speedKmh)
        try container.encode(motionState, forKey: .motionState)
        try container.encode(alert, forKey: .alert)
        try container.encode(lastSeenAt, forKey: .lastSeenAt)
    }

    public func IsLeader(in trip: Trip) -> Bool {
        id == trip.leaderParticipantID
    }

    /// Online until the last location is older than 2 minutes; exactly 2 minutes is still online.
    public func IsOnline(at date: Date) -> Bool {
        date.timeIntervalSince(lastSeenAt) <= Self.offlineAfter
    }

    /// Someone who just created or joined a trip: no location yet, stopped, no alert.
    /// - Parameter profile: `nil` uses "Member" plus the end of the iCloud user ID.
    public static func Joining(
        tripID: UUID,
        userRecordID: String,
        profile: ParticipantProfile?,
        at date: Date
    ) -> Participant {
        let profile = profile ?? ParticipantProfile.Default(forUserRecordID: userRecordID)
        return Participant(
            id: UUID(),
            tripID: tripID,
            userRecordID: userRecordID,
            displayName: profile.displayName,
            carDescription: profile.carDescription,
            isLeader: false,
            coordinate: nil,
            speedKmh: 0,
            motionState: .stopped,
            alert: .none,
            lastSeenAt: date
        )
    }
}

import Foundation

/// One person in a trip, which is also one car and one phone.
///
/// Whether they lead is not stored here: compare with `Trip.leaderParticipantID` through `IsLeader(in:)`.
struct Participant: Identifiable, Hashable, Codable, Sendable {
    /// How long a phone may go without sending a location before it counts as offline.
    static let offlineAfter: TimeInterval = 120

    /// The CloudKit record name.
    let id: UUID
    var tripID: UUID
    /// The iCloud user. Unique per trip: joining again with the same account returns this record.
    var userRecordID: String
    var displayName: String
    var carDescription: String
    /// `nil` until the phone sends its first location.
    var coordinate: Coordinate?
    var speedKmh: Double
    var motionState: MotionState
    var alert: FormationAlert
    var lastSeenAt: Date

    var name: String {
        get { displayName }
        set { displayName = newValue }
    }

    var description: String {
        get { carDescription }
        set { carDescription = newValue }
    }

    var isLeader: Bool

    enum CodingKeys: String, CodingKey {
        case id, tripID, userRecordID, displayName, carDescription
        case coordinate, speedKmh, motionState, alert, lastSeenAt
    }

    init(
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

    init(from decoder: Decoder) throws {
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

    func encode(to encoder: Encoder) throws {
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

    func IsLeader(in trip: Trip) -> Bool {
        id == trip.leaderParticipantID
    }

    /// Online until the last location is older than 2 minutes; exactly 2 minutes is still online.
    func IsOnline(at date: Date) -> Bool {
        date.timeIntervalSince(lastSeenAt) <= Self.offlineAfter
    }

    /// Someone who just created or joined a trip: no location yet, stopped, no alert.
    /// - Parameter profile: `nil` uses "Member" plus the end of the iCloud user ID.
    static func Joining(
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

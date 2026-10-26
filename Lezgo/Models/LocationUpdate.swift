import Foundation

/// One location reading from this phone, sent about once per second while a trip is open.
struct LocationUpdate: Hashable {
    var coordinate: Coordinate
    var speedKmh: Double
    var motionState: MotionState
    var recordedAt: Date
}

import Testing
@testable import Lezgo

struct TripStatusTests {
    @Test func RawValuesMatchTheStoredStrings() {
        #expect(TripStatus.allCases.map(\.rawValue) == ["LOBBY", "IN_TRIP", "ENDED", "CANCELLED"])
    }
}

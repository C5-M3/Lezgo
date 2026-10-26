import SwiftUI
import Testing
@testable import Lezgo

struct EnvironmentValuesTripServiceTests {
    @Test func ScreensWithoutASetServiceGetTheInMemoryOne() {
        #expect(EnvironmentValues().tripService is InMemoryTripService)
    }

    @Test func EveryReadReturnsTheSameDefaultService() {
        let first = EnvironmentValues().tripService as? InMemoryTripService
        let second = EnvironmentValues().tripService as? InMemoryTripService

        #expect(first != nil)
        #expect(first === second)
    }

    @Test func AppRootCanSetItsOwnService() {
        let service = InMemoryTripService()
        var environment = EnvironmentValues()

        environment.tripService = service

        #expect(environment.tripService as? InMemoryTripService === service)
    }
}

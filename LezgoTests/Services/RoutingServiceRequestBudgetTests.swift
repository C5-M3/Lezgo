//
//  RoutingServiceRequestBudgetTests.swift
//  LezgoTests
//

import CoreLocation
import Foundation
import MapKit
import Testing
@testable import Lezgo

/// MapKit answers only 50 directions requests per minute for the whole app, so the service must not ask twice for a
/// leg it already has, and must not ask at all for a calculation that was replaced.
@MainActor
struct RoutingServiceRequestBudgetTests {
    private final class FetchLog {
        var legs: [String] = []
        var failure: (any Error)?
        /// How many legs are fetched fine before `failure` is thrown.
        var failsAfter = Int.max
    }

    private func Point(_ name: String, _ latitude: Double) -> RoutePoint {
        RoutePoint(name: name, subtitle: "", coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: 113))
    }

    private func Service(_ log: FetchLog, debounce: Duration = .zero) -> RoutingService {
        RoutingService(debounce: debounce) { source, destination in
            if log.legs.count >= log.failsAfter, let failure = log.failure { throw failure }
            log.legs.append("\(source.latitude)>\(destination.latitude)")
            return [MKRoute()]
        }
    }

    private func ThrottledError(secondsUntilReset: Double?) -> NSError {
        var userInfo: [String: Any] = [:]
        if let secondsUntilReset {
            userInfo["MKErrorGEOErrorUserInfo"] = ["timeUntilReset": secondsUntilReset]
        }
        let code = Int(MKError.Code.loadingThrottled.rawValue)
        return NSError(domain: MKError.errorDomain, code: code, userInfo: userInfo)
    }

    @Test func TheSameStopsAskMapKitOnlyOnce() async throws {
        let log = FetchLog()
        let service = Service(log)
        let points = [Point("A", -1), Point("B", -2), Point("C", -3)]

        _ = try await service.calculateMultiStopLegs(points: points)
        _ = try await service.calculateMultiStopLegs(points: points)

        #expect(log.legs.count == 2)
    }

    @Test func RemovingAMiddleStopAsksOnlyForTheNewLeg() async throws {
        let log = FetchLog()
        let service = Service(log)
        let first = Point("A", -1)
        let second = Point("B", -2)
        let third = Point("C", -3)
        let fourth = Point("D", -4)

        _ = try await service.calculateMultiStopLegs(points: [first, second, third, fourth])
        _ = try await service.calculateMultiStopLegs(points: [first, second, fourth])

        #expect(log.legs.count == 4)
    }

    @Test func ALegFromTheCacheCarriesTheNamesAndPlaceOfTheNewOrder() async throws {
        let service = Service(FetchLog())
        let first = Point("A", -1)
        let second = Point("B", -2)
        let third = Point("C", -3)

        _ = try await service.calculateMultiStopLegs(points: [first, second, third])
        let legs = try await service.calculateMultiStopLegs(points: [third, first, second])

        #expect(legs.map(\.legIndex) == [0, 1])
        #expect(legs.map(\.fromName) == ["C", "A"])
        #expect(legs.map(\.toName) == ["A", "B"])
    }

    @Test func LegsFoundBeforeAThrottledOneAreKept() async throws {
        let log = FetchLog()
        log.failure = ThrottledError(secondsUntilReset: 36)
        log.failsAfter = 1
        let service = Service(log)
        let points = [Point("A", -1), Point("B", -2), Point("C", -3)]

        await #expect(throws: RoutingError.throttled(retryAfter: 36)) {
            try await service.calculateMultiStopLegs(points: points)
        }
        log.failure = nil
        _ = try await service.calculateMultiStopLegs(points: points)

        #expect(log.legs.count == 2)
    }

    @Test func AThrottledAnswerWithoutAResetTimeWaitsHalfAMinute() async {
        let log = FetchLog()
        log.failure = ThrottledError(secondsUntilReset: nil)
        log.failsAfter = 0

        await #expect(throws: RoutingError.throttled(retryAfter: 30)) {
            try await Service(log).calculateMultiStopLegs(points: [Point("A", -1), Point("B", -2)])
        }
    }

    @Test func TheResetTimeStaysWithinOneMinute() async {
        let log = FetchLog()
        log.failure = ThrottledError(secondsUntilReset: 600)
        log.failsAfter = 0

        await #expect(throws: RoutingError.throttled(retryAfter: 60)) {
            try await Service(log).calculateMultiStopLegs(points: [Point("A", -1), Point("B", -2)])
        }
    }

    @Test func OtherErrorsPassThroughUnchanged() async {
        let log = FetchLog()
        log.failure = URLError(.notConnectedToInternet)
        log.failsAfter = 0

        await #expect(throws: URLError.self) {
            try await Service(log).calculateMultiStopLegs(points: [Point("A", -1), Point("B", -2)])
        }
    }

    @Test func ACalculationReplacedWhileWaitingNeverAsksMapKit() async {
        let log = FetchLog()
        let service = Service(log, debounce: .seconds(30))
        let points = [Point("A", -1), Point("B", -2)]

        let calculation = Task { try await service.calculateMultiStopLegs(points: points) }
        calculation.cancel()
        _ = await calculation.result

        #expect(log.legs.isEmpty)
    }
}

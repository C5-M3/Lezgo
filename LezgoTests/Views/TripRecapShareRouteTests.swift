//
//  TripRecapShareRouteTests.swift
//  LezgoTests
//

import CoreGraphics
import Testing
@testable import Lezgo

struct TripRecapShareRouteTests {
    private let size = CGSize(width: 100, height: 50)

    @Test func RouteIsScaledToFitAndKeepsItsShape() {
        let points = [CGPoint(x: 10, y: 10), CGPoint(x: 30, y: 10), CGPoint(x: 30, y: 20)]

        let fitted = TripRecapShareRoute.FittedPoints(points, in: size)

        // The route is 20 wide and 10 tall, so the width limits it: a factor of 5.
        #expect(fitted == [CGPoint(x: 0, y: 0), CGPoint(x: 100, y: 0), CGPoint(x: 100, y: 50)])
    }

    @Test func TallRouteIsCenteredAcrossTheFreeWidth() {
        let points = [CGPoint(x: 0, y: 0), CGPoint(x: 10, y: 100)]

        let fitted = TripRecapShareRoute.FittedPoints(points, in: size)

        // 10 x 100 scaled by 0.5 is 5 x 50, so it sits in the middle of the 100 wide area.
        #expect(fitted == [CGPoint(x: 47.5, y: 0), CGPoint(x: 52.5, y: 50)])
    }

    @Test func RouteWithoutPointsHasNothingToDraw() {
        #expect(TripRecapShareRoute.FittedPoints([], in: size).isEmpty)
    }

    @Test func RouteOfOnePointStaysInTheMiddle() {
        let fitted = TripRecapShareRoute.FittedPoints([CGPoint(x: 7, y: 9)], in: size)

        #expect(fitted == [CGPoint(x: 50, y: 25)])
    }
}

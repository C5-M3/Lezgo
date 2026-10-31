//
//  LeaderTrail.swift
//  Lezgo
//
//  Created by Nathan Sudiara on 31/10/26.
//

import Foundation

/// The road the leader has driven.
struct LeaderTrail: Hashable {
    static let maximumPointCount = 1_500

    private(set) var points: [Coordinate]

    init(points: [Coordinate] = []) {
        self.points = points
    }

    @discardableResult
    mutating func Append(_ coordinate: Coordinate) -> Bool {
        false
    }
}

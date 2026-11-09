//
//  RouteLineEnds.swift
//  Lezgo
//
//  Created by Nathan Sudiara on 09/11/26.
//

import Foundation

/// Joins a route line to the pins it runs between. Apple's directions start and end on the nearest road, which is
/// often a few metres from the place the driver picked, so without this the line stops short of its pins and looks
/// broken.
enum RouteLineEnds {
    /// `line` with `start` added in front and `end` added behind, unless the line already begins or ends there.
    /// An empty line stays empty: a straight stroke between two pins would look like a road.
    static func Joined(_ line: [Coordinate], from start: Coordinate?, to end: Coordinate?) -> [Coordinate] {
        guard let first = line.first, let last = line.last else { return [] }
        var joined = line
        if let start, start != first { joined.insert(start, at: 0) }
        if let end, end != last { joined.append(end) }
        return joined
    }
}

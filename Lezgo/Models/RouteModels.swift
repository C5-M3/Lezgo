//
//  RouteModels.swift
//  Lezgo
//
//  Created by Farrell Sudjatmiko on 26/10/26.
//


import Foundation
import CoreLocation

struct RoutePoint: Identifiable, Equatable {
    let id: UUID
    let name: String
    let subtitle: String
    let coordinate: CLLocationCoordinate2D

    init(id: UUID = UUID(), name: String, subtitle: String, coordinate: CLLocationCoordinate2D) {
        self.id = id
        self.name = name
        self.subtitle = subtitle
        self.coordinate = coordinate
    }

    static func == (lhs: RoutePoint, rhs: RoutePoint) -> Bool {
        lhs.id == rhs.id
    }
}

enum ActivePointSelection: Identifiable, Equatable {
    case start
    case destination(index: Int)

    var id: String {
        switch self {
        case .start: return "start"
        case .destination(let index): return "destination_\(index)"
        }
    }

    var title: String {
        switch self {
        case .start: return "Starting Point"
        case .destination(let index):
            return index == 0 ? "Destination" : "Stop \(index + 1)"
        }
    }
}


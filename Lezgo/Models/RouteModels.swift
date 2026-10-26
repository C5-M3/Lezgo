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
    case stop(index: Int)
    case destination

    var id: String {
        switch self {
        case .start: return "start"
        case .stop(let index): return "stop_\(index)"
        case .destination: return "destination"
        }
    }

    var title: String {
        switch self {
        case .start: return "Starting Point"
        case .stop(let index): return "Stop \(index + 1)"
        case .destination: return "Destination"
        }
    }
}


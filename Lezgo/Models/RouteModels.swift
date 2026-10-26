//
//  RouteModels.swift
//  Lezgo
//
//  Created by Farrell Sudjatmiko on 26/10/26.
//


import Foundation
import CoreLocation

struct RoutePoint: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let subtitle: String
    let coordinate: CLLocationCoordinate2D

    static func == (lhs: RoutePoint, rhs: RoutePoint) -> Bool {
        lhs.id == rhs.id
    }
}

enum ActivePointSelection: Identifiable {
    case start
    case destination

    var id: String {
        switch self {
        case .start: return "start"
        case .destination: return "destination"
        }
    }

    var title: String {
        switch self {
        case .start: return "Set Starting Point"
        case .destination: return "Set Destination"
        }
    }
}

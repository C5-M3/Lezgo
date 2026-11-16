//
//  TripMapGuidance.swift
//  Lezgo
//
//  Created by Nathan Sudiara on 26/10/26.
//

import DeveloperToolsSupport
import Foundation

/// Turn-by-turn guidance for this phone's car: the next turn and the time left to the destination.
struct TripMapGuidance: Hashable {
    var direction: TurnDirection
    /// The instruction from the routing service, for example "Turn right". MapKit already localizes it.
    var instruction: String
    var distanceToTurn: Measurement<UnitLength>
    var timeLeft: Duration
    /// How far the car still has to drive to the destination; `nil` when the navigator cannot tell.
    var distanceLeft: Measurement<UnitLength>?
}

extension TripMapGuidance {
    /// Which way the next maneuver goes, so the turn card and CarPlay can show the matching arrow (#331).
    ///
    /// There is no roundabout arrow: roundabouts in Indonesia have three to six exits in every shape, so one arrow
    /// would mislead. A roundabout shows the way the car leaves it instead, and MapKit's instruction names the exit.
    enum TurnDirection: Hashable, CaseIterable {
        case straight
        case left
        case right
        /// A bend of less than 45 degrees ("Bear left", "Belok kiri sedikit").
        case slightLeft
        case slightRight
        /// Take the left or right side of a fork ("Keep left", "Tetap di kiri").
        case keepLeft
        case keepRight
        /// Join another road from the left or right ("Keep right to merge onto …", "… untuk masuk …").
        case mergeLeft
        case mergeRight
        /// Turn back the way the car came, turning left or right. Indonesia drives on the left, so most U-turns
        /// turn right.
        case uTurnLeft
        case uTurnRight

        /// The arrow in the asset catalog's `MapArrow` folder. The images are templates, so the view picks the color.
        var image: ImageResource {
            switch self {
            case .straight: .maneuverStraight
            case .left: .maneuverTurnLeft
            case .right: .maneuverTurnRight
            case .slightLeft: .maneuverSlightLeft
            case .slightRight: .maneuverSlightRight
            case .keepLeft: .maneuverKeepLeft
            case .keepRight: .maneuverKeepRight
            case .mergeLeft: .maneuverMergeLeft
            case .mergeRight: .maneuverMergeRight
            case .uTurnLeft: .maneuverUTurnLeft
            case .uTurnRight: .maneuverUTurnRight
            }
        }

        /// The arrow for a bend in the road of `degrees`: positive turns right, negative turns left.
        init(bend degrees: Double) {
            let size = abs(degrees)
            let isLeft = degrees < 0
            switch size {
            case ..<Self.turnDegrees: self = .straight
            case ..<Self.slightDegrees: self = isLeft ? .slightLeft : .slightRight
            case ...Self.uTurnDegrees: self = isLeft ? .left : .right
            default: self = isLeft ? .uTurnLeft : .uTurnRight
            }
        }

        /// A bend sharper than this, in degrees, is not straight on.
        static let turnDegrees = 20.0
        /// Below this a bend is slight; above it, a turn.
        static let slightDegrees = 45.0
        /// A bend sharper than this turns back.
        static let uTurnDegrees = 150.0
    }
}

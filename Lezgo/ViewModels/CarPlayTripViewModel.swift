//
//  CarPlayTripViewModel.swift
//  Lezgo
//
//  Created by Nathan Sudiara on 07/11/26.
//

import Foundation
import Observation

/// What CarPlay shows of the trip map open on the phone (ADR 0023).
@Observable
final class CarPlayTripViewModel {
    private let activeTripMap: ActiveTripMap

    init(activeTripMap: ActiveTripMap) {
        self.activeTripMap = activeTripMap
    }

    var screen: Screen { .noTrip }
    var maneuver: Maneuver? { nil }
    var tripEstimate: TripEstimate? { nil }
    var destinationName: String? { nil }
    var leaveButtonTitle: LocalizedStringResource? { nil }
    var leaveConfirmation: Confirmation? { nil }
    var alert: Alert? { nil }
    var arrival: Arrival? { nil }
    var cars: [Car] { [] }
    var selectedCar: TripMapCarStatus? { nil }

    func AlertTitle(_ alert: Alert) -> String { "" }
    func DismissAlert(_ alert: Alert) {}
    func RequestLeave() {}
    func CancelLeave() {}
    func ConfirmLeave() async {}
    func SelectCar(_ carID: UUID?) {}
    func ShowWholeRoute() {}
    func FollowMyCar() {}
}

extension CarPlayTripViewModel {
    enum Screen: Hashable {
        case noTrip, loading, onTheWay, arrived
    }

    struct Maneuver: Hashable {
        var instructionVariants: [String]
        var distance: Measurement<UnitLength>
        var symbolName: String
    }

    struct TripEstimate: Hashable {
        var timeLeft: Duration
        var distanceLeft: Measurement<UnitLength>?
    }

    struct Confirmation: Hashable {
        var title: String
        var message: String?
        var isDestructive: Bool
    }

    enum Alert: Hashable {
        case banner(TripMapAlerts.Banner)
        case notice(TripMapNotice)
    }

    struct Arrival: Hashable {
        var title: String
        var subtitle: String?
        var count: String
    }

    struct Car: Identifiable, Hashable {
        let id: UUID
        var name: String
        var isLeader: Bool
        var isMe: Bool
    }
}

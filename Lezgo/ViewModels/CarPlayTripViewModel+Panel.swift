//
//  CarPlayTripViewModel+Panel.swift
//  Lezgo
//
//  Created by Nathan Sudiara on 09/11/26.
//

import Foundation

// The map panel that replaces the phone's cards on CarPlay. In its own file so the view model file stays short.
extension CarPlayTripViewModel {
    /// What a map panel shows.
    enum Panel: Hashable {
        /// "No trip yet · Start or join a trip on your iPhone, and it shows here."
        case noTrip
        case cars([Car])
        case car(TripMapCarStatus)
        case arrival(Arrival)

        /// Panels of one kind are updated in place instead of replaced, so they do not flicker.
        func IsSameKind(as other: Panel) -> Bool {
            switch (self, other) {
            case (.noTrip, .noTrip), (.cars, .cars), (.arrival, .arrival): true
            case let (.car(this), .car(that)): this.id == that.id
            default: false
            }
        }
    }

    /// The panel to show: a picked car first, then the Cars list, then the arrival; `nil` shows only the map.
    var panel: Panel? {
        switch screen {
        case .noTrip:
            return .noTrip
        case .loading:
            return nil
        case .onTheWay, .arrived:
            if let selectedCar { return .car(selectedCar) }
            if isShowingCars { return .cars(cars) }
            return arrival.map(Panel.arrival)
        }
    }

    /// The driver closed `panel` with its close button.
    func ClosePanel(_ panel: Panel) {
        switch panel {
        case .cars: HideCars()
        case .car: SelectCar(nil)
        case .noTrip, .arrival: break
        }
    }
}

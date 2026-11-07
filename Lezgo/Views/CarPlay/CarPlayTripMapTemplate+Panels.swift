//
//  CarPlayTripMapTemplate+Panels.swift
//  Lezgo
//
//  Created by Nathan Sudiara on 07/11/26.
//

import CarPlay

// The map panels that replace the phone's cards on CarPlay: no trip yet, the Cars list, one car's status and the
// arrival. Map panels are new in iOS 27; on iOS 26 CarPlay shows the map, guidance, alerts and End Trip without them.
// In their own file so the template file stays short.
extension CarPlayTripMapTemplate {
    /// What a panel shows. A panel is only rebuilt when this changes, so it does not flicker every second.
    enum PanelContent: Hashable {
        case noTrip
        case cars([CarPlayTripViewModel.Car])
        case car(TripMapCarStatus)
        case arrival(CarPlayTripViewModel.Arrival)

        /// Panels of one kind are updated in place instead of replaced.
        func IsSameKind(as other: PanelContent) -> Bool {
            switch (self, other) {
            case (.noTrip, .noTrip), (.cars, .cars), (.arrival, .arrival): true
            case let (.car(this), .car(that)): this.id == that.id
            default: false
            }
        }
    }
}

@available(iOS 27.0, *)
extension CarPlayTripMapTemplate {
    private var shownMapPanel: CPMapPanel? {
        shownPanel as? CPMapPanel
    }

    func UpdatePanel() {
        let content = PanelContentToShow()
        guard content != shownPanelContent else { return }
        guard let content else {
            shownPanelContent = nil
            shownPanel = nil
            mapTemplate.hidePanel(completion: nil)
            return
        }
        if let shownMapPanel, let shownPanelContent, shownPanelContent.IsSameKind(as: content) {
            shownMapPanel.sections = Sections(of: content)
            self.shownPanelContent = content
            return
        }
        let panel = CPMapPanel(title: Title(of: content), sections: Sections(of: content), buttonConfiguration: nil)
        panel.showsCloseButton = content != .noTrip
        panel.delegate = self
        // Set before showing: the panel it replaces reports that it hid, and must not be taken as closed by hand.
        shownPanelContent = content
        shownPanel = panel
        mapTemplate.showPanel(panel, completion: nil)
    }

    /// A car picked on CarPlay or tapped on the phone comes first, then the Cars list, then the arrival.
    private func PanelContentToShow() -> PanelContent? {
        switch viewModel.screen {
        case .noTrip:
            isShowingCars = false
            return .noTrip
        case .loading:
            return nil
        case .onTheWay, .arrived:
            if let car = viewModel.selectedCar { return .car(car) }
            if isShowingCars { return .cars(viewModel.cars) }
            return viewModel.arrival.map(PanelContent.arrival)
        }
    }

    private func Title(of content: PanelContent) -> String {
        switch content {
        case .noTrip: String(localized: .carPlayNoTripTitle)
        case .cars: String(localized: .carPlayCars)
        case .car(let car): car.displayName
        case .arrival(let arrival): arrival.title
        }
    }

    private func Sections(of content: PanelContent) -> [CPMapPanelSection] {
        let items: [CPMapPanelItem] = switch content {
        case .noTrip: [Row(String(localized: .carPlayNoTripMessage))]
        case .cars(let cars): cars.map(CarRow)
        case .car(let car): CarStatusRows(car)
        case .arrival(let arrival):
            [arrival.subtitle.map { Row($0) }, Row(String(localized: .carPlayArrivedCount(arrival.count)))]
                .compactMap { $0 }
        }
        return [CPMapPanelSection(title: nil, items: items)]
    }

    private func CarRow(_ car: CarPlayTripViewModel.Car) -> CPMapPanelItem {
        let role: String? = if car.isMe {
            String(localized: .tripMapCarYou)
        } else if car.isLeader {
            String(localized: .tripMapCarLeader)
        } else {
            nil
        }
        let listItem = CPListItem(text: car.name, detailText: role, image: RobotImage(car.carColor))
        listItem.handler = { [weak self] _, completion in
            self?.isShowingCars = false
            self?.viewModel.SelectCar(car.id)
            completion()
        }
        return CPMapPanelItem(listItem: listItem)
    }

    /// "Driving at Ahmad Yani Street", "Black Brio" and "1 hr", as on the phone's car card.
    private func CarStatusRows(_ car: TripMapCarStatus) -> [CPMapPanelItem] {
        let timeLeft = car.timeLeft.map { $0.formatted(TripMapCarStatus.durationStyle) }
        let first = CPListItem(text: car.statusLine, detailText: timeLeft, image: RobotImage(car.carColor))
        let description = car.carDescription.isEmpty ? nil : Row(car.carDescription)
        return [CPMapPanelItem(listItem: first), description].compactMap { $0 }
    }

    private func Row(_ text: String) -> CPMapPanelItem {
        CPMapPanelItem(listItem: CPListItem(text: text, detailText: nil))
    }

    /// The car's robot from above, as on the map, at the size a CarPlay row allows.
    private func RobotImage(_ color: TripMapCarPin.CarColor) -> UIImage {
        let robot = UIImage(resource: color.TopViewImage(isGlowing: false))
        let size = CPListItem.maximumImageSize
        return UIGraphicsImageRenderer(size: size).image { _ in
            robot.draw(in: CGRect(origin: .zero, size: size))
        }
    }
}

@available(iOS 27.0, *)
extension CarPlayTripMapTemplate: CPMapPanel.Delegate {
    /// The driver closed the panel with its close button.
    func panelDidHide(_ panel: CPMapPanel) {
        guard let shownPanelContent, shownMapPanel === panel else { return }
        self.shownPanelContent = nil
        shownPanel = nil
        switch shownPanelContent {
        case .cars: isShowingCars = false
        case .car: viewModel.SelectCar(nil)
        case .noTrip, .arrival: break
        }
    }
}

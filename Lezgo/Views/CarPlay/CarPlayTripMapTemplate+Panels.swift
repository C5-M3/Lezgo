//
//  CarPlayTripMapTemplate+Panels.swift
//  Lezgo
//
//  Created by Nathan Sudiara on 07/11/26.
//

import CarPlay

// The map panels that replace the phone's cards on CarPlay: no trip yet, the Cars list, one car's status and the
// arrival. `CarPlayTripViewModel.panel` decides which; this file draws it. Map panels are new in iOS 27; on iOS 26
// CarPlay shows the map, guidance, alerts and End Trip without them. In their own file so the template file stays
// short.
@available(iOS 27.0, *)
extension CarPlayTripMapTemplate {
    private var shownMapPanel: CPMapPanel? {
        shownPanel as? CPMapPanel
    }

    func UpdatePanel() {
        let content = viewModel.panel
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
        let hadPanel = shownPanel != nil
        // Set before showing: the panel it replaces reports that it hid, and must not be taken as closed by hand.
        shownPanelContent = content
        shownPanel = panel
        guard hadPanel else {
            mapTemplate.showPanel(panel, completion: nil)
            return
        }
        // CarPlay refuses a panel while another is visible, although the guide says it replaces it.
        mapTemplate.hidePanel { [weak self] _, _ in
            Task { @MainActor [weak self] in
                guard let self, shownPanel === panel else { return }
                mapTemplate.showPanel(panel, completion: nil)
            }
        }
    }

    private func Title(of content: CarPlayTripViewModel.Panel) -> String {
        switch content {
        case .noTrip: String(localized: .carPlayNoTripTitle)
        case .cars: String(localized: .carPlayCars)
        case .car(let car): car.displayName
        case .arrival(let arrival): arrival.title
        }
    }

    private func Sections(of content: CarPlayTripViewModel.Panel) -> [CPMapPanelSection] {
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
        viewModel.ClosePanel(shownPanelContent)
    }
}

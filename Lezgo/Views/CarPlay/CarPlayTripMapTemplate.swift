//
//  CarPlayTripMapTemplate.swift
//  Lezgo
//
//  Created by Nathan Sudiara on 07/11/26.
//

import CarPlay
import MapKit

/// Everything CarPlay draws over the map, built from Apple's templates as the CarPlay Developer Guide requires of
/// navigation apps (ADR 0023): map buttons, the navigation bar, turn-by-turn guidance, navigation alerts, map panels
/// and the confirmation before leaving.
///
/// It holds no trip state of its own. It watches `CarPlayTripViewModel` and brings the templates up to date every
/// time something it read changes.
final class CarPlayTripMapTemplate: NSObject {
    let mapTemplate = CPMapTemplate()
    let viewModel: CarPlayTripViewModel
    private weak var interfaceController: CPInterfaceController?

    private var navigationSession: CPNavigationSession?
    private var navigationTrip: CPTrip?
    /// The maneuver on the guidance panel, to update its distance instead of replacing it.
    private var shownManeuver: (maneuver: CarPlayTripViewModel.Maneuver, template: CPManeuver)?
    /// CarPlay cancelled guidance, for example because the car's own navigation started. Guidance must stop at once
    /// and stays off until the next trip.
    private var isGuidanceCancelledByCarPlay = false

    private var shownAlert: CarPlayTripViewModel.Alert?
    private var shownConfirmation: CarPlayTripViewModel.Confirmation?
    private var shownLeaveError: String?

    /// `true` while the list opened with the Cars button is open.
    var isShowingCars = false
    var shownPanelContent: PanelContent?
    /// The `CPMapPanel` on screen. A stored property cannot be limited to iOS 27, where map panels start.
    var shownPanel: NSObject?

    init(viewModel: CarPlayTripViewModel, interfaceController: CPInterfaceController) {
        self.viewModel = viewModel
        self.interfaceController = interfaceController
        super.init()
        mapTemplate.mapDelegate = self
        mapTemplate.mapButtons = [
            MapButton(
                symbolName: "point.topleft.down.to.point.bottomright.curvepath",
                action: viewModel.ShowWholeRoute
            ),
            MapButton(symbolName: "location.fill", action: viewModel.FollowMyCar)
        ]
        Observe()
    }

    /// Updates the templates now, and again whenever anything they read from the view model changes.
    private func Observe() {
        withObservationTracking {
            Update()
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in self?.Observe() }
        }
    }

    private func Update() {
        UpdateNavigationBar()
        UpdateGuidance()
        UpdateAlert()
        UpdateLeaveConfirmation()
        if #available(iOS 27.0, *) { UpdatePanel() }
    }

    private func MapButton(symbolName: String, action: @escaping () -> Void) -> CPMapButton {
        let button = CPMapButton { _ in action() }
        button.image = UIImage(systemName: symbolName)
        return button
    }
}

// MARK: Navigation bar

extension CarPlayTripMapTemplate {
    private func UpdateNavigationBar() {
        guard let leaveTitle = viewModel.leaveButtonTitle else {
            mapTemplate.leadingNavigationBarButtons = []
            mapTemplate.trailingNavigationBarButtons = []
            return
        }
        let leave = CPBarButton(title: String(localized: leaveTitle)) { [weak self] _ in
            self?.viewModel.RequestLeave()
        }
        mapTemplate.trailingNavigationBarButtons = [leave]
        // The Cars list is a map panel, which starts in iOS 27.
        guard #available(iOS 27.0, *) else { return }
        let cars = CPBarButton(title: String(localized: .carPlayCars)) { [weak self] _ in self?.ShowCars() }
        mapTemplate.leadingNavigationBarButtons = [cars]
    }

    @available(iOS 27.0, *)
    private func ShowCars() {
        viewModel.SelectCar(nil)
        isShowingCars = true
        UpdatePanel()
    }
}

// MARK: Guidance

extension CarPlayTripMapTemplate {
    private func UpdateGuidance() {
        guard viewModel.screen == .onTheWay, isGuidanceCancelledByCarPlay == false else {
            EndGuidance()
            if viewModel.screen == .noTrip { isGuidanceCancelledByCarPlay = false }
            return
        }
        let session = navigationSession ?? StartGuidance()
        if viewModel.isRerouting {
            session.pauseTrip(for: .rerouting, description: nil)
            shownManeuver = nil
        } else if let maneuver = viewModel.maneuver {
            ShowManeuver(maneuver, in: session)
        } else if shownManeuver == nil {
            session.pauseTrip(for: .loading, description: nil)
        }
        UpdateTripEstimate()
    }

    private func StartGuidance() -> CPNavigationSession {
        let destination = MKMapItem.forCurrentLocation()
        destination.name = viewModel.destinationName
        let routeChoice = CPRouteChoice(
            summaryVariants: [viewModel.destinationName ?? ""],
            additionalInformationVariants: [],
            selectionSummaryVariants: []
        )
        let trip = CPTrip(origin: MKMapItem.forCurrentLocation(), destination: destination, routeChoices: [routeChoice])
        let session = mapTemplate.startNavigationSession(for: trip)
        session.pauseTrip(for: .loading, description: nil)
        navigationTrip = trip
        navigationSession = session
        return session
    }

    private func ShowManeuver(_ maneuver: CarPlayTripViewModel.Maneuver, in session: CPNavigationSession) {
        let estimates = CPTravelEstimates(distanceRemaining: maneuver.distance, timeRemaining: 0)
        // Only the distance changed: CarPlay moves the number without redrawing the turn.
        if let shownManeuver, shownManeuver.maneuver.instructionVariants == maneuver.instructionVariants,
           shownManeuver.maneuver.symbolName == maneuver.symbolName {
            session.updateEstimates(estimates, for: shownManeuver.template)
            self.shownManeuver = (maneuver, shownManeuver.template)
            return
        }
        let template = CPManeuver()
        template.instructionVariants = maneuver.instructionVariants
        template.symbolImage = ManeuverSymbol(maneuver.symbolName)
        template.initialTravelEstimates = estimates
        session.upcomingManeuvers = [template]
        shownManeuver = (maneuver, template)
    }

    private func UpdateTripEstimate() {
        guard let navigationTrip, let estimate = viewModel.tripEstimate else { return }
        let distance = estimate.distanceLeft ?? Measurement(value: 0, unit: UnitLength.kilometers)
        let seconds = TimeInterval(estimate.timeLeft.components.seconds)
        let estimates = CPTravelEstimates(distanceRemaining: distance, timeRemaining: seconds)
        mapTemplate.updateEstimates(estimates, for: navigationTrip)
    }

    /// The car has arrived, or the trip is gone: the guidance panel closes.
    private func EndGuidance() {
        guard let navigationSession else { return }
        if viewModel.screen == .arrived {
            navigationSession.finishTrip()
        } else {
            navigationSession.cancelTrip()
        }
        self.navigationSession = nil
        navigationTrip = nil
        shownManeuver = nil
    }

    /// The arrow with light and dark variants: dark on a light panel, Lezgo yellow on a dark one.
    private func ManeuverSymbol(_ symbolName: String) -> UIImage? {
        let configuration = UIImage.SymbolConfiguration(pointSize: 40, weight: .bold)
        guard let symbol = UIImage(systemName: symbolName, withConfiguration: configuration) else { return nil }
        let light = symbol.withTintColor(.black, renderingMode: .alwaysOriginal)
        let dark = symbol.withTintColor(UIColor(resource: .brandYellow), renderingMode: .alwaysOriginal)
        let asset = UIImageAsset()
        asset.register(light, with: UITraitCollection(userInterfaceStyle: .light))
        asset.register(dark, with: UITraitCollection(userInterfaceStyle: .dark))
        return asset.image(with: .current)
    }
}

// MARK: Alerts

extension CarPlayTripMapTemplate {
    /// Formation alerts and notices become navigation alerts, silent like on the phone. One at a time: a new one
    /// replaces the old one.
    private func UpdateAlert() {
        let alert = viewModel.alert
        guard alert != shownAlert else { return }
        shownAlert = alert
        mapTemplate.dismissNavigationAlert(animated: true) { [weak self] _ in
            guard let self, let alert, alert == shownAlert else { return }
            mapTemplate.present(navigationAlert: NavigationAlert(for: alert), animated: true)
        }
    }

    private func NavigationAlert(for alert: CarPlayTripViewModel.Alert) -> CPNavigationAlert {
        let close = CPAlertAction(title: String(localized: .tripMapOK), style: .cancel) { [weak self] _ in
            self?.viewModel.DismissAlert(alert)
        }
        return CPNavigationAlert(
            titleVariants: [viewModel.AlertTitle(alert)],
            subtitleVariants: nil,
            image: AlertSymbol(for: alert),
            primaryAction: close,
            secondaryAction: nil,
            duration: TimeInterval(viewModel.AlertDuration(alert) ?? 0)
        )
    }

    /// Red for a car that has stopped or a notice that something is wrong, as on the phone's pill.
    private func AlertSymbol(for alert: CarPlayTripViewModel.Alert) -> UIImage? {
        let isUrgent = switch alert {
        case .banner(let banner): banner.isUrgent
        case .notice(let notice): notice.isUrgent
        }
        let color = isUrgent ? UIColor(resource: .tripAlertRed) : UIColor(resource: .brandYellow)
        return UIImage(systemName: "exclamationmark.circle.fill")?.withTintColor(color, renderingMode: .alwaysOriginal)
    }
}

// MARK: Leave and end

extension CarPlayTripMapTemplate {
    /// "Exit trip?" or "End trip?" asked on CarPlay, as on the phone: leaving is destructive (AGENTS.md, "Safety").
    private func UpdateLeaveConfirmation() {
        let confirmation = viewModel.leaveConfirmation
        let leaveError = viewModel.leaveErrorMessage
        guard confirmation != shownConfirmation || leaveError != shownLeaveError else { return }
        let hadAlert = shownConfirmation != nil || shownLeaveError != nil
        shownConfirmation = confirmation
        shownLeaveError = leaveError
        let next = confirmation.map(ConfirmationAlert) ?? leaveError.map(LeaveErrorAlert)
        guard hadAlert else {
            if let next { interfaceController?.presentTemplate(next, animated: true, completion: nil) }
            return
        }
        interfaceController?.dismissTemplate(animated: true) { [weak self] _, _ in
            guard let next else { return }
            self?.interfaceController?.presentTemplate(next, animated: true, completion: nil)
        }
    }

    private func ConfirmationAlert(_ confirmation: CarPlayTripViewModel.Confirmation) -> CPAlertTemplate {
        let cancel = CPAlertAction(title: String(localized: .tripMapCancel), style: .cancel) { [weak self] _ in
            self?.viewModel.CancelLeave()
        }
        let confirm = CPAlertAction(
            title: String(localized: .tripMapConfirm),
            style: confirmation.isDestructive ? .destructive : .default
        ) { [weak self] _ in
            Task { await self?.viewModel.ConfirmLeave() }
        }
        // An alert has no message line, so the longest variant that fits carries the explanation too.
        let titles = confirmation.message.map { ["\(confirmation.title) \($0)", confirmation.title] }
        return CPAlertTemplate(titleVariants: titles ?? [confirmation.title], actions: [cancel, confirm])
    }

    private func LeaveErrorAlert(_ message: String) -> CPAlertTemplate {
        let close = CPAlertAction(title: String(localized: .tripMapOK), style: .cancel) { [weak self] _ in
            self?.viewModel.DismissLeaveError()
        }
        return CPAlertTemplate(titleVariants: [message], actions: [close])
    }
}

// MARK: CPMapTemplateDelegate

extension CarPlayTripMapTemplate: CPMapTemplateDelegate {
    /// The car's own navigation, or Siri with another app, took over: stop guidance at once (navigation rule 6).
    func mapTemplateDidCancelNavigation(_ mapTemplate: CPMapTemplate) {
        isGuidanceCancelledByCarPlay = true
        navigationSession = nil
        navigationTrip = nil
        shownManeuver = nil
    }
}

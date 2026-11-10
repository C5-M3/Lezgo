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
    /// Why guidance is paused, so CarPlay is told once and not on every GPS update.
    private var pausedFor: CPNavigationSession.PauseReason?
    /// Where the guided trip ends; a new destination starts a new trip.
    private var guidedDestination: Coordinate?

    /// The navigation bar's buttons. The bar is only rebuilt when they change: a button replaced while the driver
    /// taps it drops the tap.
    private var shownBar: NavigationBar?
    /// The one map button: the whole route, or back to this car.
    private lazy var cameraButton = CPMapButton { [weak self] _ in self?.viewModel.ToggleCamera() }
    /// Which of its two icons the camera button shows; `nil` before the first update.
    private var shownFollowingMyCar: Bool?
    private var shownAlert: CarPlayTripViewModel.Alert?
    private var shownModalAlert: ModalAlert?

    var shownPanelContent: CarPlayTripViewModel.Panel?
    /// The `CPMapPanel` on screen. A stored property cannot be limited to iOS 27, where map panels start.
    var shownPanel: NSObject?

    init(viewModel: CarPlayTripViewModel, interfaceController: CPInterfaceController) {
        self.viewModel = viewModel
        self.interfaceController = interfaceController
        super.init()
        mapTemplate.mapDelegate = self
        // The dark turn card of the Sketch design, with the yellow arrow.
        mapTemplate.guidanceBackgroundColor = UIColor(resource: .tripCard)
        mapTemplate.tripEstimateStyle = .dark
        mapTemplate.mapButtons = [cameraButton]
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
        UpdateCameraButton()
        UpdateNavigationBar()
        UpdateGuidance()
        UpdateAlert()
        UpdateModalAlert()
        if #available(iOS 27.0, *) { UpdatePanel() }
    }

    /// Shows what a tap does, as in Apple Maps: the whole route while the camera follows this car, otherwise the
    /// arrow that takes the camera back to the car.
    private func UpdateCameraButton() {
        let isFollowingMyCar = viewModel.isFollowingMyCar
        guard isFollowingMyCar != shownFollowingMyCar else { return }
        shownFollowingMyCar = isFollowingMyCar
        cameraButton.image = UIImage(
            systemName: isFollowingMyCar ? "point.topleft.down.to.point.bottomright.curvepath" : "location.fill"
        )
    }
}

// MARK: Navigation bar

extension CarPlayTripMapTemplate {
    /// What the navigation bar holds, compared as text: two equal `LocalizedStringResource` values do not always
    /// compare equal.
    private struct NavigationBar: Equatable {
        var leaveTitle: String?
        var canResumeGuidance: Bool
    }

    private func UpdateNavigationBar() {
        let bar = NavigationBar(
            leaveTitle: viewModel.leaveButtonTitle.map { String(localized: $0) },
            canResumeGuidance: viewModel.canResumeGuidance
        )
        guard bar != shownBar else { return }
        shownBar = bar
        guard let leaveTitle = bar.leaveTitle else {
            mapTemplate.leadingNavigationBarButtons = []
            mapTemplate.trailingNavigationBarButtons = []
            return
        }
        let leave = CPBarButton(title: leaveTitle) { [weak self] _ in
            self?.viewModel.RequestLeave()
        }
        mapTemplate.trailingNavigationBarButtons = [leave]
        var leading: [CPBarButton] = []
        // The Cars list is a map panel, which starts in iOS 27.
        if #available(iOS 27.0, *) {
            leading.append(CPBarButton(title: String(localized: .carPlayCars)) { [weak self] _ in self?.ShowCars() })
        }
        if bar.canResumeGuidance {
            leading.append(CPBarButton(title: String(localized: .carPlayResumeGuidance)) { [weak self] _ in
                self?.viewModel.ResumeGuidance()
            })
        }
        mapTemplate.leadingNavigationBarButtons = leading
    }

    @available(iOS 27.0, *)
    private func ShowCars() {
        viewModel.ShowCars()
        UpdatePanel()
    }
}

// MARK: Guidance

extension CarPlayTripMapTemplate {
    private func UpdateGuidance() {
        let guidance = viewModel.guidance
        guard guidance != .off, guidance != .cancelledByCarPlay else {
            EndGuidance()
            return
        }
        if navigationSession != nil, guidedDestination != viewModel.destinationCoordinate {
            EndGuidance()
        }
        let session = navigationSession ?? StartGuidance()
        switch guidance {
        case .rerouting:
            Pause(session, for: .rerouting)
            shownManeuver = nil
        case .turn(let maneuver):
            pausedFor = nil
            ShowManeuver(maneuver, in: session)
        case .loading:
            // A turn already on the panel stays until the next one is known.
            if shownManeuver == nil { Pause(session, for: .loading) }
        case .off, .cancelledByCarPlay:
            break
        }
        UpdateTripEstimate()
    }

    private func Pause(_ session: CPNavigationSession, for reason: CPNavigationSession.PauseReason) {
        guard pausedFor != reason else { return }
        pausedFor = reason
        session.pauseTrip(for: reason, description: nil)
    }

    private func StartGuidance() -> CPNavigationSession {
        let coordinate = viewModel.destinationCoordinate
        // Without a destination stop yet, the trip still needs an end; CarPlay only shows its name then.
        let destination = coordinate.map {
            MKMapItem(location: CLLocation(latitude: $0.latitude, longitude: $0.longitude), address: nil)
        } ?? MKMapItem.forCurrentLocation()
        destination.name = viewModel.destinationName
        let routeChoice = CPRouteChoice(
            summaryVariants: [viewModel.destinationName ?? ""],
            additionalInformationVariants: [],
            selectionSummaryVariants: []
        )
        let trip = CPTrip(origin: MKMapItem.forCurrentLocation(), destination: destination, routeChoices: [routeChoice])
        let session = mapTemplate.startNavigationSession(for: trip)
        navigationTrip = trip
        navigationSession = session
        guidedDestination = coordinate
        pausedFor = nil
        Pause(session, for: .loading)
        return session
    }

    private func ShowManeuver(_ maneuver: CarPlayTripViewModel.Maneuver, in session: CPNavigationSession) {
        let estimates = CPTravelEstimates(distanceRemaining: RoadDistance(maneuver.distance), timeRemaining: 0)
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
        let estimates = CPTravelEstimates(distanceRemaining: RoadDistance(distance), timeRemaining: seconds)
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
        ForgetGuidance()
    }

    private func ForgetGuidance() {
        navigationSession = nil
        navigationTrip = nil
        shownManeuver = nil
        pausedFor = nil
        guidedDestination = nil
    }

    /// "3,4 km" or "200 m", as a road sign says it. CarPlay prints the number in the unit it is given, so 3 401 m
    /// would read "3.401 m".
    private func RoadDistance(_ distance: Measurement<UnitLength>) -> Measurement<UnitLength> {
        let metres = distance.converted(to: .meters).value
        guard metres >= 1_000 else { return Measurement(value: (metres / 10).rounded() * 10, unit: .meters) }
        return Measurement(value: (metres / 100).rounded() / 10, unit: .kilometers)
    }

    /// The yellow arrow for the dark turn card. Drawn into a bitmap: CarPlay sends the image on to the car's
    /// screen, and a symbol image does not always arrive there.
    private func ManeuverSymbol(_ symbolName: String) -> UIImage? {
        let configuration = UIImage.SymbolConfiguration(pointSize: 40, weight: .bold)
        guard let symbol = UIImage(systemName: symbolName, withConfiguration: configuration)?
            .withTintColor(UIColor(resource: .brandYellow), renderingMode: .alwaysOriginal) else { return nil }
        let format = UIGraphicsImageRendererFormat()
        format.scale = 3
        return UIGraphicsImageRenderer(size: symbol.size, format: format).image { _ in
            symbol.draw(at: .zero)
        }
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

// MARK: Leave, end and closed trips

extension CarPlayTripMapTemplate {
    /// The one full-screen alert CarPlay shows at a time.
    private enum ModalAlert: Equatable {
        /// "Exit trip?" or "End trip?", as on the phone: leaving is destructive (AGENTS.md, "Safety").
        case confirmation(CarPlayTripViewModel.Confirmation)
        /// Leaving failed, for example without a network.
        case leaveError(String)
        /// Another phone closed the trip: "The leader ended the trip."
        case closed(String)
    }

    private func UpdateModalAlert() {
        let next: ModalAlert? = viewModel.leaveConfirmation.map(ModalAlert.confirmation)
            ?? viewModel.leaveErrorMessage.map(ModalAlert.leaveError)
            ?? viewModel.closeMessage.map(ModalAlert.closed)
        guard next != shownModalAlert else { return }
        let hadAlert = shownModalAlert != nil
        shownModalAlert = next
        let template = next.map(Template)
        guard hadAlert else {
            if let template { interfaceController?.presentTemplate(template, animated: true, completion: nil) }
            return
        }
        interfaceController?.dismissTemplate(animated: true) { [weak self] _, _ in
            guard let template else { return }
            self?.interfaceController?.presentTemplate(template, animated: true, completion: nil)
        }
    }

    private func Template(for alert: ModalAlert) -> CPAlertTemplate {
        switch alert {
        case .confirmation(let confirmation): ConfirmationAlert(confirmation)
        case .leaveError(let message): MessageAlert(message) { [weak self] in self?.viewModel.DismissLeaveError() }
        case .closed(let message): MessageAlert(message) { [weak self] in self?.viewModel.DismissCloseMessage() }
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

    private func MessageAlert(_ message: String, onClose: @escaping () -> Void) -> CPAlertTemplate {
        let close = CPAlertAction(title: String(localized: .tripMapOK), style: .cancel) { _ in onClose() }
        return CPAlertTemplate(titleVariants: [message], actions: [close])
    }
}

// MARK: CPMapTemplateDelegate

extension CarPlayTripMapTemplate: CPMapTemplateDelegate {
    /// The car's own navigation, or Siri with another app, took over: stop guidance at once (navigation rule 6).
    /// The driver can turn guidance back on with "Resume".
    func mapTemplateDidCancelNavigation(_ mapTemplate: CPMapTemplate) {
        ForgetGuidance()
        viewModel.CancelGuidance()
    }
}

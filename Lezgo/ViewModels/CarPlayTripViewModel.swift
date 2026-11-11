//
//  CarPlayTripViewModel.swift
//  Lezgo
//
//  Created by Nathan Sudiara on 07/11/26.
//

import Foundation
import Observation

/// What CarPlay shows of the trip map open on the phone (ADR 0023).
///
/// It owns no trip of its own: it reads the phone's `TripMapViewModel` through `ActiveTripMap` and turns it into what
/// Apple's CarPlay templates need, so the car and the phone always agree. Buttons on CarPlay call the same trip map.
@Observable
final class CarPlayTripViewModel {
    /// A CarPlay map panel holds at most 12 items (CarPlay Developer Guide, "General purpose").
    static let maxCars = 12

    private let activeTripMap: ActiveTripMap

    /// The trip map whose guidance CarPlay cancelled. Kept per trip map, so the next trip starts with guidance.
    private var guidanceCancelledFor: ObjectIdentifier?
    /// The trip map whose Cars list is open, so the next trip starts with it closed.
    private var carsShownFor: ObjectIdentifier?
    /// The closed trip map whose message the driver closed on CarPlay.
    private var closeMessageDismissedFor: ObjectIdentifier?

    init(activeTripMap: ActiveTripMap) {
        self.activeTripMap = activeTripMap
    }

    /// The trip map CarPlay mirrors: the one open on the phone, until its trip closes there.
    private var tripMap: TripMapViewModel? {
        guard let tripMap = activeTripMap.tripMap, tripMap.closeReason == nil else { return nil }
        return tripMap
    }

    var screen: Screen {
        guard let tripMap else { return .noTrip }
        if tripMap.isLoading { return .loading }
        return tripMap.arrivalCard == nil ? .onTheWay : .arrived
    }

    /// The next turn for the guidance panel; `nil` before guidance is known, while rerouting and after arriving.
    var maneuver: Maneuver? {
        guard screen == .onTheWay, let tripMap, tripMap.isRerouting == false, let guidance = tripMap.guidance else {
            return nil
        }
        // MapKit often gives the first step no text, and CarPlay needs at least one instruction.
        let instruction = guidance.instruction.isEmpty
            ? tripMap.destinationName.map { String(localized: .tripMapToDestination($0)) }
            : guidance.instruction
        guard let instruction else { return nil }
        return Maneuver(
            instructionVariants: [instruction],
            distance: guidance.distanceToTurn,
            symbolName: guidance.direction.symbolName
        )
    }

    /// What the guidance panel shows now.
    var guidance: Guidance {
        guard screen == .onTheWay, let tripMap else { return .off }
        if guidanceCancelledFor == ObjectIdentifier(tripMap) { return .cancelledByCarPlay }
        if isRerouting { return .rerouting }
        return maneuver.map(Guidance.turn) ?? .loading
    }

    /// After CarPlay cancelled guidance, the driver can turn it back on.
    var canResumeGuidance: Bool {
        guidance == .cancelledByCarPlay
    }

    /// CarPlay cancelled guidance, for example because the car's own navigation started (navigation rule 6).
    func CancelGuidance() {
        guidanceCancelledFor = tripMap.map(ObjectIdentifier.init)
    }

    func ResumeGuidance() {
        guidanceCancelledFor = nil
    }

    /// `true` while a new route is on its way; CarPlay then pauses guidance as "Rerouting".
    var isRerouting: Bool {
        screen == .onTheWay && tripMap?.isRerouting == true
    }

    /// The time and distance left to the destination ("50 min · To Tunjungan Plaza" on the phone).
    var tripEstimate: TripEstimate? {
        guard screen == .onTheWay, let tripMap, let guidance = tripMap.guidance else { return nil }
        let distanceLeft = guidance.distanceLeft ?? RouteAheadLength(tripMap)
        return TripEstimate(timeLeft: guidance.timeLeft, distanceLeft: distanceLeft)
    }

    /// How long the road still ahead is, for when the navigator cannot tell how far is left.
    private func RouteAheadLength(_ tripMap: TripMapViewModel) -> Measurement<UnitLength>? {
        let path = tripMap.routeAhead
        guard path.count > 1 else { return nil }
        let metres = zip(path, path.dropFirst()).reduce(0) { $0 + $1.0.Distance(to: $1.1) }
        return Measurement(value: metres, unit: .meters)
    }

    var destinationName: String? {
        tripMap?.destinationName
    }

    /// Where the guided trip ends, for the car's dashboard and instrument cluster.
    var destinationCoordinate: Coordinate? {
        tripMap?.state?.destination?.coordinate
    }

    /// Why the trip closed when another phone closed it, as the phone says it: "The leader ended the trip."
    var closeMessage: String? {
        guard let closed = activeTripMap.tripMap, closeMessageDismissedFor != ObjectIdentifier(closed) else {
            return nil
        }
        switch closed.closeReason {
        case .endedByLeader: return String(localized: .tripMapLeaderEndedTrip)
        case .removed: return String(localized: .tripMapRemovedFromTrip)
        case .backToTripRoom, .exited, .ended, nil: return nil
        }
    }

    func DismissCloseMessage() {
        closeMessageDismissedFor = activeTripMap.tripMap.map(ObjectIdentifier.init)
    }

    /// "End Trip" for the leader, "Exit Trip" for a member; `nil` without a trip.
    var leaveButtonTitle: LocalizedStringResource? {
        guard let tripMap, tripMap.isLoading == false else { return nil }
        return tripMap.isLeader ? .tripMapEndTrip : .tripMapExitTrip
    }

    /// The question asked before leaving, the same as on the phone (`specs/UserStories.md` → US-07).
    var leaveConfirmation: Confirmation? {
        switch tripMap?.leaveConfirmation {
        case nil:
            nil
        case .exitTrip:
            Confirmation(
                title: String(localized: .tripMapExitTripQuestion),
                message: String(localized: .tripMapExitTripMessage),
                isDestructive: false
            )
        case .endTrip(let everyoneHasArrived):
            Confirmation(
                title: String(localized: .tripMapEndTripQuestion),
                message: everyoneHasArrived ? nil : String(localized: .tripMapEndTripNotEveryoneMessage),
                isDestructive: true
            )
        }
    }

    /// Why leaving failed, for example no network.
    var leaveErrorMessage: String? {
        tripMap?.leaveErrorMessage
    }

    /// The one alert to show as a CarPlay navigation alert: a formation alert first, then a notice about the route.
    var alert: Alert? {
        guard let tripMap else { return nil }
        if let banner = tripMap.alertBanner { return .banner(banner) }
        return tripMap.noticeBanner.map(Alert.notice)
    }

    /// What arrives at the destination, with how many cars are there ("2/3"); `nil` while on the way.
    var arrival: Arrival? {
        guard let tripMap, let card = tripMap.arrivalCard, let progress = tripMap.arrivalProgress else { return nil }
        return Arrival(
            title: String(localized: card.title),
            subtitle: card.Subtitle(isLeader: tripMap.isLeader).map { String(localized: $0) },
            count: "\(progress.arrivedCount)/\(progress.totalCount)"
        )
    }

    /// The cars on the map, leader first, for the Cars panel.
    var cars: [Car] {
        guard let tripMap, let state = tripMap.state else { return [] }
        let onMap = state.participants.filter { $0.coordinate != nil }
        let leaders = onMap.filter { $0.IsLeader(in: state.trip) }
        let leaderFirst = leaders + onMap.filter { $0.IsLeader(in: state.trip) == false }
        return leaderFirst.prefix(Self.maxCars).map { participant in
            Car(
                id: participant.id,
                name: state.DisplayName(of: participant),
                isLeader: participant.IsLeader(in: state.trip),
                isMe: participant.id == tripMap.myParticipantID,
                carColor: tripMap.CarColor(of: participant, in: state)
            )
        }
    }

    /// `true` while the list opened with the Cars button is open.
    var isShowingCars: Bool {
        guard let tripMap else { return false }
        return carsShownFor == ObjectIdentifier(tripMap)
    }

    /// The Cars button: closes a picked car and lists every car.
    func ShowCars() {
        SelectCar(nil)
        carsShownFor = tripMap.map(ObjectIdentifier.init)
    }

    func HideCars() {
        carsShownFor = nil
    }

    /// The picked car's status, as on the phone's car card.
    var selectedCar: TripMapCarStatus? {
        tripMap?.selectedCarStatus
    }

    func AlertTitle(_ alert: Alert) -> String {
        switch alert {
        case .banner(let banner): String(localized: banner.message)
        case .notice(let notice): notice.Message(timeLeft: tripMap?.guidance?.timeLeft)
        }
    }

    /// How long CarPlay shows the alert, in seconds; `nil` keeps it until it is closed or no longer true.
    func AlertDuration(_ alert: Alert) -> Int? {
        guard case .notice(let notice) = alert else { return nil }
        return notice.secondsOnScreen
    }

    /// The alert was closed on CarPlay: it stays away until it happens again, on the phone too.
    func DismissAlert(_ alert: Alert) {
        guard let tripMap else { return }
        switch alert {
        case .banner(let banner):
            guard tripMap.alertBanner == banner else { return }
            tripMap.DismissAlertBanner()
        case .notice(let notice):
            tripMap.DismissNotice(notice)
        }
    }

    func RequestLeave() {
        tripMap?.RequestLeave()
    }

    func CancelLeave() {
        tripMap?.CancelLeave()
    }

    /// Leaves or ends the trip after the driver confirmed on CarPlay.
    func ConfirmLeave() async {
        // Kept here: once the trip closes, `tripMap` reads `nil`.
        guard let tripMap, let confirmation = tripMap.leaveConfirmation else { return }
        await tripMap.ConfirmLeave(confirmation)
    }

    func DismissLeaveError() {
        tripMap?.DismissLeaveError()
    }

    /// Opens a car's status in place of the Cars list and focuses the camera on it; `nil` closes it.
    func SelectCar(_ carID: UUID?) {
        if carID != nil { carsShownFor = nil }
        tripMap?.SelectCar(carID)
    }

    /// `true` while the camera follows this phone's car: the camera button then offers the whole route, and
    /// otherwise the way back to the car. Without a trip there is nothing else to follow.
    var isFollowingMyCar: Bool {
        tripMap.map { $0.cameraMode == .followMyCar } ?? true
    }

    /// The one camera button, as on the phone and in Apple Maps.
    func ToggleCamera() {
        tripMap?.ToggleCamera()
    }

    func ZoomIn() {
        tripMap?.ZoomIn()
    }

    func ZoomOut() {
        tripMap?.ZoomOut()
    }
}

extension CarPlayTripViewModel {
    /// What the CarPlay map shows.
    enum Screen: Hashable {
        /// No trip map is open on the phone: "Start or join a trip on your iPhone".
        case noTrip
        /// The trip map is waiting for its first update.
        case loading
        /// Driving, with turn-by-turn guidance.
        case onTheWay
        /// This car has arrived at the destination.
        case arrived
    }

    /// What the guidance panel shows.
    enum Guidance: Hashable {
        /// No trip on the way: no trip, still loading, or arrived.
        case off
        /// Waiting for the first turn.
        case loading
        /// A new route is on its way.
        case rerouting
        case turn(Maneuver)
        /// CarPlay cancelled guidance; it stays off until the driver resumes it.
        case cancelledByCarPlay
    }

    /// The next turn, as CarPlay's `CPManeuver` needs it.
    struct Maneuver: Hashable {
        /// Longest first, as CarPlay picks the longest that fits.
        var instructionVariants: [String]
        var distance: Measurement<UnitLength>
        var symbolName: String
    }

    struct TripEstimate: Hashable {
        var timeLeft: Duration
        var distanceLeft: Measurement<UnitLength>?
    }

    /// "Exit trip?" or "End trip?" with its explanation.
    struct Confirmation: Hashable {
        var title: String
        var message: String?
        /// End Trip ends it for everyone, so its button is red.
        var isDestructive: Bool
    }

    enum Alert: Hashable {
        /// A formation alert: "You're out of the way", "Citra has stopped".
        case banner(TripMapAlerts.Banner)
        /// A notice about the route or the leader: "New route · Following Agus".
        case notice(TripMapNotice)
    }

    /// "You have arrived!" · "Waiting for everyone to arrive" · "2/3"
    struct Arrival: Hashable {
        var title: String
        var subtitle: String?
        var count: String
    }

    /// A row in the Cars panel.
    struct Car: Identifiable, Hashable {
        let id: UUID
        var name: String
        var isLeader: Bool
        var isMe: Bool
        var carColor: TripMapCarPin.CarColor
    }
}

//
//  TripMapView.swift
//  Lezgo
//
//  Created by Nathan Sudiara on 26/10/26.
//

import MapKit
import SwiftUI

/// The trip map (Trip Started screen): the shared route, its waypoints and every car, with the next turn on top
/// and a sheet at the bottom, as in Apple Maps.
struct TripMapView: View {
    @State private var viewModel: TripMapViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @Environment(\.dismiss) private var dismiss
    /// How far the sheet is pulled up. It starts collapsed, so End Trip and Exit Trip are out of reach while driving.
    @State private var sheetDetent: PresentationDetent = .custom(CollapsedSheet.self)
    /// `false` while Edit Route is open: the planner has its own sheet, and stacked on top of this one SwiftUI stops
    /// updating it, so its buttons seem stuck.
    @State private var showsSheet = true
    /// The planner on screen, set only once the sheet has gone, and cleared when the planner closes.
    @State private var presentedEditRoute: EditRouteViewModel?

    /// Returns to Home once the map closes; `nil` dismisses the map.
    private let onClose: (() -> Void)?
    /// Opens the Trip Room with the trip back in `LOBBY` after a New Destination; `nil` hides "New Destination".
    private let onReturnToTripRoom: ((TripSession) -> Void)?

    init(
        viewModel: TripMapViewModel,
        onClose: (() -> Void)? = nil,
        onReturnToTripRoom: ((TripSession) -> Void)? = nil
    ) {
        _viewModel = State(initialValue: viewModel)
        self.onClose = onClose
        self.onReturnToTripRoom = onReturnToTripRoom
    }

    var body: some View {
        // The map closes the car status on a tap (below) but is not a button, so it gets no button trait;
        // VoiceOver closes it with its Close button or the escape gesture instead.
        // swiftlint:disable:next accessibility_trait_for_button
        MapLayer(viewModel: viewModel)
        // Tapping the map anywhere but a car closes the car status.
        .onTapGesture { viewModel.SelectCar(nil) }
        .safeAreaInset(edge: .top) {
            VStack(alignment: .trailing) {
                // After arriving there is no next turn; the sheet says what to do instead.
                if viewModel.arrivalCard == nil, let guidance = viewModel.guidance {
                    TripMapTurnCard(guidance: guidance)
                }
                if viewModel.isLocationImprecise {
                    PreciseLocationNotice()
                } else if viewModel.isConnectionLost {
                    ConnectionLostNotice()
                }
                if let alertBanner = viewModel.alertBanner {
                    // A fade, not a slide: sliding in, the banner would pass behind the glass turn card.
                    TripMapAlertBanner(banner: alertBanner, onClose: viewModel.DismissAlertBanner)
                        .transition(.opacity)
                }
                TripMapCameraControls(
                    cameraMode: viewModel.cameraMode,
                    showWholeRoute: viewModel.ShowWholeRoute,
                    followMyCar: FollowMyCarAction()
                )
            }
            .padding(.horizontal)
            .animation(reduceMotion ? nil : .default, value: viewModel.alertBanner)
        }
        // There all the time, like the sheet in Apple Maps: it cannot be swiped away, and the map works behind it.
        // It steps aside only for Edit Route, which opens once it has gone.
        .sheet(isPresented: $showsSheet, onDismiss: ShowEditRoute) {
            TripMapSheet(viewModel: viewModel, onNewDestination: NewDestinationAction())
                .presentationDetents([.custom(CollapsedSheet.self), .medium, .large], selection: $sheetDetent)
                .presentationBackgroundInteraction(.enabled(upThrough: .medium))
                .presentationDragIndicator(.visible)
                .interactiveDismissDisabled()
                // The sheet is on top, so everything it opens is presented from it.
                .modifier(Dialogs(viewModel: viewModel, close: Close))
        }
        .fullScreenCover(item: $presentedEditRoute, onDismiss: HideEditRoute) { editRoute in
            EditRouteView(viewModel: editRoute, onClose: viewModel.CloseEditRoute)
        }
        .onChange(of: viewModel.editRoute?.id) {
            if viewModel.editRoute == nil {
                presentedEditRoute = nil
            } else {
                showsSheet = false
            }
        }
        .task { await viewModel.Start() }
        .task(id: viewModel.selectedCarID) { await viewModel.TrackSelectedCar() }
        .onChange(of: viewModel.selectedCarID) {
            // A car tapped in the list: the sheet goes down so the car shows on the map.
            if viewModel.selectedCarID != nil { sheetDetent = .custom(CollapsedSheet.self) }
        }
        .onChange(of: viewModel.arrivalCard) {
            // Arriving is when the driver chooses what is next, so the sheet comes up with the choices.
            if viewModel.arrivalCard != nil { sheetDetent = .medium }
        }
        .onChange(of: viewModel.closeReason) {
            // Leaving on purpose needs no message: go straight back to Home.
            if viewModel.closeReason == .exited || viewModel.closeReason == .ended {
                Close()
            }
            if let session = viewModel.tripRoomSession {
                onReturnToTripRoom?(session)
            }
        }
    }

    /// The sheet has gone: opens Edit Route if it is still wanted, otherwise brings the sheet back.
    private func ShowEditRoute() {
        if let editRoute = viewModel.editRoute {
            presentedEditRoute = editRoute
        } else {
            showsSheet = true
        }
    }

    /// Edit Route has closed: the sheet comes back.
    private func HideEditRoute() {
        viewModel.CloseEditRoute()
        showsSheet = true
    }

    private func Close() {
        if let onClose {
            onClose()
        } else {
            dismiss()
        }
    }

    /// "New Destination" shows only where the screen that opened the map can take everyone back to the Trip Room.
    private func NewDestinationAction() -> (() -> Void)? {
        guard onReturnToTripRoom != nil else { return nil }
        return viewModel.RequestNewDestination
    }

    /// The map's own location button follows the car when it is the location dot; then this button is hidden.
    private func FollowMyCarAction() -> (() -> Void)? {
        guard viewModel.showsMyLocationDot == false else { return nil }
        return viewModel.FollowMyCar
    }
}

extension TripMapView {
    /// The collapsed sheet: just tall enough for its top (the destination, a tapped car or the arrival message),
    /// and taller with bigger text.
    struct CollapsedSheet: CustomPresentationDetent {
        static func height(in context: Context) -> CGFloat? {
            switch context.dynamicTypeSize {
            case ...DynamicTypeSize.large: 140
            case ...DynamicTypeSize.xxxLarge: 170
            default: 260
            }
        }
    }

    /// The questions and messages about leaving the trip.
    struct Dialogs: ViewModifier {
        let viewModel: TripMapViewModel
        /// Goes back to Home once someone else ended the trip or removed this member.
        let close: () -> Void

        func body(content: Content) -> some View {
            content
                .alert(
                    Text(LeaveQuestion()),
                    isPresented: IsAskingToLeave(),
                    presenting: viewModel.leaveConfirmation
                ) { confirmation in
                    Button(role: .cancel, action: viewModel.CancelLeave) { Text(.tripMapCancel) }
                    Button(role: viewModel.isLeader ? .destructive : nil) {
                        Task { await viewModel.ConfirmLeave(confirmation) }
                    } label: {
                        Text(.tripMapConfirm)
                    }
                }
                .alert(Text(verbatim: viewModel.leaveErrorMessage ?? ""), isPresented: HasLeaveError()) {
                    Button(action: viewModel.DismissLeaveError) { Text(.tripMapOK) }
                }
                .alert(Text(ClosedMessage()), isPresented: IsTellingWhyItClosed()) {
                    Button(action: close) { Text(.tripMapOK) }
                }
        }

        private func LeaveQuestion() -> LocalizedStringResource {
            switch viewModel.leaveConfirmation {
            case .endTrip(everyoneHasArrived: false): .tripMapEndTripNotEveryoneArrived
            case .endTrip: .tripMapEndTripQuestion
            case .exitTrip, nil: .tripMapExitTripQuestion
            }
        }

        private func ClosedMessage() -> LocalizedStringResource {
            viewModel.closeReason == .removed ? .tripMapRemovedFromTrip : .tripMapLeaderEndedTrip
        }

        private func IsAskingToLeave() -> Binding<Bool> {
            Binding(get: { viewModel.leaveConfirmation != nil }, set: { if $0 == false { viewModel.CancelLeave() } })
        }

        private func HasLeaveError() -> Binding<Bool> {
            Binding(
                get: { viewModel.leaveErrorMessage != nil },
                set: { if $0 == false { viewModel.DismissLeaveError() } }
            )
        }

        private func IsTellingWhyItClosed() -> Binding<Bool> {
            Binding(
                get: { viewModel.closeReason == .endedByLeader || viewModel.closeReason == .removed },
                set: { _ in }
            )
        }
    }
}

extension TripMapView {
    /// The map itself: the route, the waypoints, this phone's location dot and the other cars. Its own view, so the
    /// screen's body stays small enough for the compiler.
    struct MapLayer: View {
        let viewModel: TripMapViewModel
        @State private var cameraPosition: MapCameraPosition = .automatic
        /// The cars as drawn: they follow `viewModel.carPins` with an animation, so a car glides to its new
        /// position instead of jumping there every second.
        @State private var carPins: [TripMapCarPin] = []
        /// Which way the map is turned, so the cars' direction pointers match the streets.
        @State private var mapHeading: Double = 0
        @Environment(\.accessibilityReduceMotion) private var reduceMotion

        /// How far above the car the camera floats while following it, in metres.
        private static let followDistance: CLLocationDistance = 1_500

        init(viewModel: TripMapViewModel) {
            self.viewModel = viewModel
        }

        var body: some View {
            Map(position: $cameraPosition) {
                // Only what is still ahead, as in Apple Maps: the part already driven and the stops passed go away.
                MapPolyline(coordinates: viewModel.routeAhead.map(\.locationCoordinate))
                    .stroke(.tint, style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round))

                ForEach(viewModel.upcomingWaypoints) { waypoint in
                    Annotation(waypoint.name, coordinate: waypoint.coordinate.locationCoordinate, anchor: .bottom) {
                        TripMapWaypointPinView(waypoint: waypoint)
                    }
                }

                if viewModel.showsMyLocationDot {
                    UserAnnotation()
                }

                ForEach(carPins) { pin in
                    Annotation(pin.displayName, coordinate: pin.coordinate.locationCoordinate) {
                        Button { viewModel.SelectCar(pin.id) } label: {
                            TripMapCarPinView(
                                pin: pin,
                                isSelected: pin.id == viewModel.selectedCarID,
                                mapHeading: mapHeading
                            )
                        }
                        .buttonStyle(.plain)
                    }
                    .annotationTitles(.hidden)
                }
            }
            .mapStyle(.standard(pointsOfInterest: .excludingAll))
            .mapControls {
                // As in Apple Maps: one tap follows the car, a second tap turns the map the way the car drives.
                if viewModel.showsMyLocationDot {
                    MapUserLocationButton()
                }
                MapCompass()
            }
            .onMapCameraChange(frequency: .continuous) { context in
                mapHeading = context.camera.heading
            }
            .onMapCameraChange(frequency: .onEnd) {
                // Panning or zooming by hand stops the camera from jumping back to the car every second.
                if cameraPosition.positionedByUser {
                    viewModel.StopFollowing()
                }
            }
            .onAppear(perform: MoveCamera)
            .onChange(of: viewModel.myCoordinate) {
                // The location dot camera follows the car by itself.
                if viewModel.showsMyLocationDot == false { MoveCamera() }
            }
            .onChange(of: viewModel.cameraMode) { MoveCamera() }
            .onChange(of: viewModel.route) { MoveCamera() }
            .onChange(of: viewModel.carPins, initial: true) { ShowCarPins() }
            .onChange(of: cameraPosition.followsUserLocation) {
                // The map's location button follows the car without going through the view model.
                if cameraPosition.followsUserLocation { viewModel.FollowMyCar() }
            }
        }

        /// Moves the cars to their new positions over about the time between two updates, so they glide.
        private func ShowCarPins() {
            if reduceMotion {
                carPins = viewModel.carPins
            } else {
                withAnimation(.linear(duration: 1)) { carPins = viewModel.carPins }
            }
        }

        private func MoveCamera() {
            guard let target = CameraTarget() else { return }
            if reduceMotion {
                cameraPosition = target
            } else {
                withAnimation(.easeInOut) { cameraPosition = target }
            }
        }

        private func CameraTarget() -> MapCameraPosition? {
            switch viewModel.cameraMode {
            case .followMyCar where viewModel.showsMyLocationDot:
                // Already following (for example after the location button): setting it again would undo the
                // button's choice between north up and heading up.
                guard cameraPosition.followsUserLocation == false else { return nil }
                return .userLocation(followsHeading: true, fallback: .automatic)
            case .followMyCar:
                guard let myCoordinate = viewModel.myCoordinate else { return nil }
                let camera = MapCamera(centerCoordinate: myCoordinate.locationCoordinate, distance: Self.followDistance)
                return .camera(camera)
            case .wholeRoute:
                guard viewModel.route.isEmpty == false else { return nil }
                return .rect(RouteRect())
            case .free:
                return nil
            }
        }

        /// The smallest map rectangle around the route, with a margin so the end pins are not cut off.
        private func RouteRect() -> MKMapRect {
            let rect = viewModel.route
                .map { MKMapPoint($0.locationCoordinate) }
                .reduce(MKMapRect.null) { $0.union(MKMapRect(origin: $1, size: MKMapSize(width: 0, height: 0))) }
            return rect.insetBy(dx: -rect.width * 0.15, dy: -rect.height * 0.15)
        }
    }
}

extension TripMapView {
    /// A quiet notice under the turn card while this phone cannot send its position (#220). It is not an alert:
    /// the driver needs no action, and it goes away by itself when the connection is back.
    struct ConnectionLostNotice: View {
        var body: some View {
            Label(.tripMapConnectionLost, systemImage: "wifi.slash")
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal)
                .padding(.vertical, 8)
                .glassEffect(in: .capsule)
                .accessibilityAddTraits(.isStaticText)
        }
    }
}

#Preview("Connection lost") {
    TripMapView.ConnectionLostNotice()
        .padding()
}

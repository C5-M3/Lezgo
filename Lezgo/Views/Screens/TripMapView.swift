//
//  TripMapView.swift
//  Lezgo
//
//  Created by Nathan Sudiara on 26/10/26.
//

import MapKit
import SwiftUI

/// The trip map (Trip Started screen): the shared route, its waypoints and every car, with the next turn on top
/// and the destination and time left at the bottom.
struct TripMapView: View {
    @State private var viewModel: TripMapViewModel
    @State private var cameraPosition: MapCameraPosition = .automatic
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// How far above the car the camera floats while following it, in metres.
    private static let followDistance: CLLocationDistance = 1_500

    @Environment(\.dismiss) private var dismiss

    /// Opens the New Destination planner (#115); `nil` hides the button.
    private let onNewDestination: (() -> Void)?
    /// Returns to Home once the map closes; `nil` dismisses the map.
    private let onClose: (() -> Void)?

    init(
        viewModel: TripMapViewModel,
        onNewDestination: (() -> Void)? = nil,
        onClose: (() -> Void)? = nil
    ) {
        _viewModel = State(initialValue: viewModel)
        self.onNewDestination = onNewDestination
        self.onClose = onClose
    }

    var body: some View {
        // The map closes the car status card on a tap (below) but is not a button, so it gets no button trait;
        // VoiceOver closes the card with its Close action or the escape gesture instead.
        // swiftlint:disable:next accessibility_trait_for_button
        Map(position: $cameraPosition) {
            MapPolyline(coordinates: viewModel.route.map(\.locationCoordinate))
                .stroke(.tint, style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round))

            ForEach(viewModel.waypoints) { waypoint in
                Annotation(waypoint.name, coordinate: waypoint.coordinate.locationCoordinate, anchor: .bottom) {
                    TripMapWaypointPinView(waypoint: waypoint, isVisited: viewModel.IsVisited(waypoint))
                }
            }

            ForEach(viewModel.carPins) { pin in
                Annotation(pin.displayName, coordinate: pin.coordinate.locationCoordinate) {
                    Button { viewModel.SelectCar(pin.id) } label: {
                        TripMapCarPinView(pin: pin, isSelected: pin.id == viewModel.selectedCarID)
                    }
                    .buttonStyle(.plain)
                }
                .annotationTitles(.hidden)
            }
        }
        .mapStyle(.standard(pointsOfInterest: .excludingAll))
        // Tapping the map anywhere but a car closes the car status card.
        .onTapGesture { viewModel.SelectCar(nil) }
        .safeAreaInset(edge: .top) {
            // After arriving there is no next turn; the arrival card says what to do instead.
            if viewModel.arrivalCard == nil, let guidance = viewModel.guidance {
                TripMapTurnCard(guidance: guidance)
                    .padding(.horizontal)
            }
        }
        .safeAreaInset(edge: .bottom) {
            VStack(alignment: .trailing) {
                TripMapCameraControls(
                    cameraMode: viewModel.cameraMode,
                    showWholeRoute: viewModel.ShowWholeRoute,
                    followMyCar: viewModel.FollowMyCar
                )
                if let carStatus = viewModel.selectedCarStatus {
                    TripMapCarStatusCard(status: carStatus, onClose: { viewModel.SelectCar(nil) })
                } else if let arrivalCard = viewModel.arrivalCard {
                    TripMapArrivalCardView(
                        card: arrivalCard,
                        isLeader: viewModel.isLeader,
                        onNewDestination: onNewDestination,
                        onLeave: viewModel.RequestLeave
                    )
                    .disabled(viewModel.isLeaving)
                } else if let destinationName = viewModel.destinationName {
                    TripMapBottomCard(
                        destinationName: destinationName,
                        timeLeft: viewModel.guidance?.timeLeft,
                        isLeader: viewModel.isLeader,
                        onLeave: viewModel.RequestLeave
                    )
                    .disabled(viewModel.isLeaving)
                }
            }
            .padding(.horizontal)
        }
        .overlay {
            if viewModel.isLoading {
                ProgressView(.tripMapLoading)
                    .padding()
                    .background(.regularMaterial, in: .rect(cornerRadius: 16))
            }
        }
        .task { await viewModel.Start() }
        .task(id: viewModel.selectedCarID) { await viewModel.TrackSelectedCar() }
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
            Button(action: Close) { Text(.tripMapOK) }
        }
        .onChange(of: viewModel.closeReason) {
            // Leaving on purpose needs no message: go straight back to Home.
            if viewModel.closeReason == .exited || viewModel.closeReason == .ended {
                Close()
            }
        }
        .onChange(of: viewModel.myCoordinate) { MoveCamera() }
        .onChange(of: viewModel.cameraMode) { MoveCamera() }
        .onChange(of: viewModel.route) { MoveCamera() }
        .onMapCameraChange(frequency: .onEnd) {
            // Panning or zooming by hand stops the camera from jumping back to the car every second.
            if cameraPosition.positionedByUser {
                viewModel.StopFollowing()
            }
        }
    }

    private func Close() {
        if let onClose {
            onClose()
        } else {
            dismiss()
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
        Binding(get: { viewModel.leaveErrorMessage != nil }, set: { if $0 == false { viewModel.DismissLeaveError() } })
    }

    private func IsTellingWhyItClosed() -> Binding<Bool> {
        Binding(
            get: { viewModel.closeReason == .endedByLeader || viewModel.closeReason == .removed },
            set: { _ in }
        )
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
        case .followMyCar:
            guard let myCoordinate = viewModel.myCoordinate else { return nil }
            return .camera(MapCamera(centerCoordinate: myCoordinate.locationCoordinate, distance: Self.followDistance))
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

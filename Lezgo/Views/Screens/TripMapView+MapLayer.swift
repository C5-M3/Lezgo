//
//  TripMapView+MapLayer.swift
//  Lezgo
//
//  Created by Nathan Sudiara on 26/10/26.
//

import MapKit
import SwiftUI

extension TripMapView {
    /// The map itself: the route, the waypoints, this phone's location dot and the other cars. Its own view, so the
    /// screen's body stays small enough for the compiler.
    struct MapLayer: View {
        let viewModel: TripMapViewModel
        /// `false` hides the cars until the "Lez Go!" animation has opened the map.
        let showsCars: Bool
        @State private var cameraPosition: MapCameraPosition = .automatic
        /// The cars as drawn: they follow `viewModel.carPins` with an animation, so a car glides to its new
        /// position instead of jumping there every second.
        @State private var carPins: [TripMapCarPin] = []
        /// Which way the map is turned, so the cars' direction pointers match the streets.
        @State private var mapHeading: Double = 0
        /// How much of the world the map shows across, and how wide the map is, to tell which cars would overlap.
        @State private var visibleWidthInMetres = 0.0
        @State private var mapWidth = 0.0
        @Environment(\.accessibilityReduceMotion) private var reduceMotion

        /// Cars closer than this on screen would overlap, in points.
        private static let groupDistance = 60.0
        /// How far above the car the camera floats while following it, in metres.
        private static let followDistance: CLLocationDistance = 1_500

        init(viewModel: TripMapViewModel, showsCars: Bool = true) {
            self.viewModel = viewModel
            self.showsCars = showsCars
        }

        var body: some View {
            Map(position: $cameraPosition) {
                // On the leader's map, the road the leader has driven: the members behind follow it, so the leader
                // can see them on it. Dotted and faint, so it never reads as the way to go.
                MapPolyline(coordinates: viewModel.footprint.map(\.locationCoordinate))
                    .stroke(
                        Color(.brandYellow).opacity(0.5),
                        style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round, dash: [0.5, 10])
                    )

                // On the leader's map, where a member who left the road is being sent. Dashed and in the colour of
                // that car's alert, so it never reads as the leader's own route.
                ForEach(viewModel.memberWayBacks) { wayBack in
                    MapPolyline(coordinates: wayBack.path.map(\.locationCoordinate))
                        .stroke(
                            Color(.formationAlertBackground),
                            style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round, dash: [10, 10])
                        )
                }

                // Only what is still ahead, as in Apple Maps: the part already driven and the stops passed go away.
                MapPolyline(coordinates: viewModel.routeAhead.map(\.locationCoordinate))
                    .stroke(Color(.tripCard), style: StrokeStyle(lineWidth: 16, lineCap: .round, lineJoin: .round))
                MapPolyline(coordinates: viewModel.routeAhead.map(\.locationCoordinate))
                    .stroke(Color(.brandYellow), style: StrokeStyle(lineWidth: 8, lineCap: .round, lineJoin: .round))

                ForEach(viewModel.upcomingWaypoints) { waypoint in
                    Annotation(waypoint.name, coordinate: waypoint.coordinate.locationCoordinate, anchor: .bottom) {
                        TripMapWaypointPinView(waypoint: waypoint)
                    }
                }

                if viewModel.showsMyLocationDot {
                    UserAnnotation()
                }

                ForEach(CarGroups()) { group in
                    Annotation(group.pins[0].displayName, coordinate: group.coordinate.locationCoordinate) {
                        CarGroupContent(group: group)
                            .scaleEffect(showsCars ? 1 : 0)
                    }
                    .annotationTitles(.hidden)
                }
            }
            .mapStyle(.standard(emphasis: .muted, pointsOfInterest: .excludingAll))
            .mapControls {
                MapCompass()
            }
            .onMapCameraChange(frequency: .continuous) { context in
                mapHeading = context.camera.heading
            }
            .onMapCameraChange(frequency: .onEnd) { context in
                // Panning or zooming by hand stops the camera from jumping back to the car every second.
                if cameraPosition.positionedByUser {
                    viewModel.StopFollowing()
                }
                let metresPerMapPoint = 1 / MKMapPointsPerMeterAtLatitude(context.camera.centerCoordinate.latitude)
                visibleWidthInMetres = context.rect.width * metresPerMapPoint
            }
            .onGeometryChange(for: CGFloat.self, of: \.size.width) { mapWidth = Double($0) }
            .onAppear(perform: MoveCamera)
            .onChange(of: viewModel.myCoordinate) {
                // The location dot camera follows the car by itself.
                if viewModel.showsMyLocationDot == false { MoveCamera() }
            }
            .onChange(of: viewModel.cameraMode) { MoveCamera() }
            .onChange(of: viewModel.route) { MoveCamera() }
            .onChange(of: viewModel.carPins, initial: true) { ShowCarPins() }
        }

        private func CarGroups() -> [TripMapCarGroup] {
            let metresPerPoint = mapWidth > 0 ? visibleWidthInMetres / mapWidth : 0
            return TripMapCarGroup.Make(
                pins: carPins,
                selectedID: viewModel.selectedCarID,
                within: metresPerPoint * Self.groupDistance
            )
        }

        @ViewBuilder
        private func CarGroupContent(group: TripMapCarGroup) -> some View {
            if group.pins.count == 1 {
                Button { viewModel.SelectCar(group.pins[0].id) } label: {
                    TripMapCarPinView(
                        pin: group.pins[0],
                        isSelected: group.pins[0].id == viewModel.selectedCarID,
                        mapHeading: mapHeading
                    )
                }
                .buttonStyle(.plain)
            } else {
                TripMapCarGroupView(group: group, onSelect: viewModel.SelectCar)
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
                // Already following: setting it again would restart the camera's move.
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

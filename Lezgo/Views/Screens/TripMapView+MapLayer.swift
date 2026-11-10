//
//  TripMapView+MapLayer.swift
//  Lezgo
//
//  Created by Nathan Sudiara on 26/10/26.
//

import MapKit
import SwiftUI

extension TripMapView {
    /// The map itself: the route, the waypoints and every car, this phone's own one included. Its own view, so the
    /// screen's body stays small enough for the compiler.
    struct MapLayer: View {
        let viewModel: TripMapViewModel
        /// `false` hides the cars until the "Lez Go!" animation has opened the map.
        let showsCars: Bool
        /// Which way the map is turned, for the phone's compass button; `nil` on CarPlay, where the map may show
        /// nothing but the map (ADR 0023).
        let compassHeading: TripMapHeading?
        @State private var cameraPosition: MapCameraPosition = .automatic
        /// The cars as drawn: they follow `viewModel.carPins` with an animation, so a car glides to its new
        /// position instead of jumping there every second.
        @State private var carPins: [TripMapCarPin] = []
        /// Which way the map is turned, so the cars' direction pointers match the streets.
        @State private var mapHeading: Double = 0
        /// Where the camera is now, so the compass can turn the map back to north from right here.
        @State private var mapCamera: MapCamera?
        /// How much of the world the map shows across, and how wide the map is, to tell which cars would overlap.
        @State private var visibleWidthInMetres = 0.0
        @State private var mapWidth = 0.0
        @Environment(\.accessibilityReduceMotion) private var reduceMotion

        /// Cars closer than this on screen would overlap, in points.
        private static let groupDistance = 60.0
        /// How far above the car the camera floats while following it, in metres.
        private static let followDistance: CLLocationDistance = 1_500

        init(viewModel: TripMapViewModel, showsCars: Bool = true, compassHeading: TripMapHeading? = nil) {
            self.viewModel = viewModel
            self.showsCars = showsCars
            self.compassHeading = compassHeading
        }

        var body: some View {
            Map(position: $cameraPosition) {
                // Where another member who left the road is being sent. Dashed and in the colour of that car's
                // robot, so it never reads as this phone's own route.
                ForEach(viewModel.wayBacks) { wayBack in
                    MapPolyline(coordinates: wayBack.path.map(\.locationCoordinate))
                        .stroke(
                            wayBack.carColor.color,
                            style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round, dash: [10, 10])
                        )
                }

                // The group's route from the last car on, and this phone's own way back to it.
                ForEach(RouteLines()) { line in
                    RouteLineMapContent(coordinates: line.coordinates)
                }

                ForEach(viewModel.upcomingWaypoints) { waypoint in
                    Annotation(waypoint.name, coordinate: waypoint.coordinate.locationCoordinate, anchor: .bottom) {
                        TripMapWaypointPinView(waypoint: waypoint)
                    }
                }

                ForEach(CarGroups()) { group in
                    Annotation(group.pins[0].displayName, coordinate: group.coordinate.locationCoordinate) {
                        CarGroupMarker(group: group, viewModel: viewModel, mapHeading: mapHeading)
                            .scaleEffect(showsCars ? 1 : 0)
                    }
                    .annotationTitles(.hidden)
                }
            }
            .mapStyle(.lezgo)
            // Apple's compass is Liquid Glass; the phone draws its own with the round map buttons (`TripMapCompass`).
            .mapControls {}
            .onMapCameraChange(frequency: .continuous) { context in
                mapHeading = context.camera.heading
                mapCamera = context.camera
                compassHeading?.Update(context.camera.heading)
            }
            .onChange(of: compassHeading?.northRequest) { PointNorth() }
            .onMapCameraChange(frequency: .onEnd) { context in
                // Panning or zooming by hand stops the camera from jumping back to the car every second.
                if cameraPosition.positionedByUser {
                    viewModel.StopFollowing()
                    // A camera button move cut short by the next tap stops wherever it was, even over the sea:
                    // finish the move to what the button chose.
                    if viewModel.cameraMode != .free { MoveCamera() }
                }
                let metresPerMapPoint = 1 / MKMapPointsPerMeterAtLatitude(context.camera.centerCoordinate.latitude)
                visibleWidthInMetres = context.rect.width * metresPerMapPoint
            }
            .onGeometryChange(for: CGFloat.self, of: \.size.width) { mapWidth = Double($0) }
            .onAppear(perform: MoveCamera)
            .onChange(of: viewModel.myCoordinate) {
                // The camera following the phone's location moves with the car by itself.
                if viewModel.followsPhoneLocation == false { MoveCamera() }
            }
            .onChange(of: viewModel.cameraMode) { MoveCamera() }
            .onChange(of: viewModel.route) { MoveCamera() }
            .onChange(of: viewModel.carPins, initial: true) {
                ShowCarPins()
                // A tapped car is followed as it moves, gliding with its robot.
                if case .followCar = viewModel.cameraMode { MoveCamera(animation: .linear(duration: 1)) }
            }
        }

        /// The yellow lines: the group's route, and this phone's own way back to it while there is one.
        private func RouteLines() -> [RouteLine] {
            [RouteLine(id: "route", path: viewModel.routeLine), RouteLine(id: "wayBack", path: viewModel.myWayBack)]
                .filter { $0.coordinates.count > 1 }
        }

        private func CarGroups() -> [TripMapCarGroup] {
            let metresPerPoint = mapWidth > 0 ? visibleWidthInMetres / mapWidth : 0
            return TripMapCarGroup.Make(pins: carPins, within: metresPerPoint * Self.groupDistance)
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
            MoveCamera(animation: .easeInOut)
        }

        /// The compass: turns the map back to north. A camera turning with the car keeps following it, facing north.
        private func PointNorth() {
            let north: MapCameraPosition
            if cameraPosition.followsUserLocation {
                north = .userLocation(followsHeading: false, fallback: .automatic)
            } else if let mapCamera {
                north = .camera(MapCamera(
                    centerCoordinate: mapCamera.centerCoordinate,
                    distance: mapCamera.distance,
                    heading: 0,
                    pitch: mapCamera.pitch
                ))
            } else {
                return
            }
            if reduceMotion {
                cameraPosition = north
            } else {
                withAnimation(.easeInOut) { cameraPosition = north }
            }
        }

        private func MoveCamera(animation: Animation) {
            guard let target = CameraTarget() else { return }
            if reduceMotion {
                cameraPosition = target
            } else {
                withAnimation(animation) { cameraPosition = target }
            }
        }

        private func CameraTarget() -> MapCameraPosition? {
            switch viewModel.cameraMode {
            case .followMyCar where viewModel.followsPhoneLocation:
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
            case .followCar(let carID):
                guard let car = viewModel.carPins.first(where: { $0.id == carID }) else { return nil }
                // The map keeps its turn, so the streets do not spin while it moves to the car.
                let camera = MapCamera(
                    centerCoordinate: car.coordinate.locationCoordinate,
                    distance: Self.followDistance,
                    heading: mapHeading
                )
                return .camera(camera)
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

extension TripMapView.MapLayer {
    /// A car on its own or a card of cars close together. It reads the tapped car from the view model itself: the map
    /// keeps an annotation's view while its group is unchanged, so a value passed in would not redraw the glow.
    struct CarGroupMarker: View {
        let group: TripMapCarGroup
        let viewModel: TripMapViewModel
        let mapHeading: Double

        var body: some View {
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
                TripMapCarGroupView(group: group, selectedID: viewModel.selectedCarID, onSelect: viewModel.SelectCar)
            }
        }
    }
}

extension TripMapView.MapLayer {
    /// One yellow line on the map, named so the map keeps drawing it as the same line while it changes.
    struct RouteLine: Identifiable {
        let id: String
        let coordinates: [CLLocationCoordinate2D]

        init(id: String, path: [Coordinate]) {
            self.id = id
            coordinates = path.map(\.locationCoordinate)
        }
    }
}

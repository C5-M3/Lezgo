//
//  DraftTripView+Map.swift
//  Lezgo
//
//  Created by Rizal Pratama on 27/10/26.
//

import MapKit
import SwiftUI
import UIKit

extension DraftTripView {
    /// Non-interactive background map displaying the saved trip route.
    struct MapView: View {
        @Binding var cameraPosition: MapCameraPosition
        let primaryCoordinates: [CLLocationCoordinate2D]
        let primaryBadgeCoordinate: CLLocationCoordinate2D?
        let primaryDurationText: String
        let startCoordinate: Coordinate?
        let destinationCoordinate: Coordinate?
        let destinationName: String

        /// The route joined to the robot and the flag, so it does not stop on the nearest road.
        private var joinedCoordinates: [CLLocationCoordinate2D] {
            let line = primaryCoordinates.map { Coordinate(latitude: $0.latitude, longitude: $0.longitude) }
            return RouteLineEnds.Joined(line, from: startCoordinate, to: destinationCoordinate)
                .map(\.locationCoordinate)
        }

        var body: some View {
            Map(position: $cameraPosition, interactionModes: []) {
                if !primaryCoordinates.isEmpty {
                    RouteLineMapContent(coordinates: joinedCoordinates)
                }

                // Primary route duration badge positioned in the middle, slightly above the route
                if let badgeCoord = primaryBadgeCoordinate, !primaryDurationText.isEmpty {
                    Annotation("", coordinate: badgeCoord) {
                        Text(primaryDurationText)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.black)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color(.brandYellow))
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .shadow(color: .black.opacity(0.35), radius: 6, y: 3)
                            .offset(y: -30)
                    }
                }

                // Start point marker: the leader's robot, as in the hi-fi
                if let start = startCoordinate {
                    Annotation("", coordinate: start.locationCoordinate) {
                        Image(.ontripNoglowYellow)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 56, height: 56)
                            .accessibilityHidden(true)
                    }
                }

                // Destination marker: the shared yellow flag pin, with the destination name
                if let destination = destinationCoordinate {
                    Annotation("", coordinate: destination.locationCoordinate) {
                        VStack(spacing: 4) {
                            RouteStopPin(kind: .destination)

                            Text(destinationName)
                                .font(.footnote.weight(.bold))
                                .foregroundStyle(.white)
                                .shadow(color: .black.opacity(0.85), radius: 3, x: 0, y: 1)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: 140)
                        }
                    }
                }
            }
            .mapStyle(.lezgo)
            // The badges are map graphics of a fixed size, as on the trip map; bigger text would cover the route.
            .dynamicTypeSize(...DynamicTypeSize.xLarge)
            .mapControlVisibility(.hidden)
            .disabled(true)
            .allowsHitTesting(false)
            .ignoresSafeArea()
        }
    }

    /// Dark gradient fading from transparent over the map to black at the bottom.
    struct GradientOverlay: View {
        var body: some View {
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0.0),
                    .init(color: .clear, location: 0.28),
                    .init(color: .black.opacity(0.6), location: 0.45),
                    .init(color: .black, location: 0.56),
                    .init(color: .black, location: 1.0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)
        }
    }

    // MARK: - Safe Area Helpers

    static func EffectiveTopInset(from geometry: GeometryProxy) -> CGFloat {
        if geometry.safeAreaInsets.top > 0 {
            return geometry.safeAreaInsets.top
        }
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let windows = scenes.flatMap { $0.windows }
        if let maxInset = windows.map(\.safeAreaInsets.top).max(), maxInset > 0 {
            return maxInset
        }
        if geometry.size.height >= 800 {
            return 59
        }
        return 0
    }

    static func EffectiveBottomInset(from geometry: GeometryProxy) -> CGFloat {
        if geometry.safeAreaInsets.bottom > 0 {
            return geometry.safeAreaInsets.bottom
        }
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let windows = scenes.flatMap { $0.windows }
        if let maxInset = windows.map(\.safeAreaInsets.bottom).max(), maxInset > 0 {
            return maxInset
        }
        if geometry.size.height >= 800 {
            return 34
        }
        return 0
    }

    // MARK: - Map Rect Calculation

    static func ComputeTargetMapRect(
        coordinates: [CLLocationCoordinate2D],
        bottomContentHeight: CGFloat,
        size: CGSize,
        topInset: CGFloat
    ) -> MKMapRect {
        var allCoords = coordinates
        if allCoords.isEmpty {
            allCoords = [
                CLLocationCoordinate2D(latitude: -7.2858, longitude: 112.6318),
                CLLocationCoordinate2D(latitude: -7.2923, longitude: 112.7190)
            ]
        }

        var baseRect: MKMapRect = .null
        for coord in allCoords {
            let point = MKMapPoint(coord)
            baseRect = baseRect.union(MKMapRect(x: point.x, y: point.y, width: 0, height: 0))
        }

        if baseRect.isNull || baseRect.isEmpty, let firstCoord = allCoords.first {
            let centerPoint = MKMapPoint(firstCoord)
            baseRect = MKMapRect(x: centerPoint.x - 4000, y: centerPoint.y - 4000, width: 8000, height: 8000)
        }

        // Add 25% margin around the route bounding box (minimum 2500 map points for close coordinates)
        let marginX = max(baseRect.size.width * 0.25, 2500)
        let marginY = max(baseRect.size.height * 0.25, 2500)
        let paddedWidth = max(baseRect.size.width + (2 * marginX), 10000)
        let paddedHeight = max(baseRect.size.height + (2 * marginY), 10000)

        let screenWidth = size.width > 0 ? size.width : 393
        let screenHeight = size.height > 0 ? size.height : 852
        let bottomHeight = bottomContentHeight > 0 ? bottomContentHeight : 390
        let visibleTop = topInset
        let visibleBottom = max(screenHeight - bottomHeight, visibleTop + 100)
        let visibleHeight = max(visibleBottom - visibleTop, 100)
        let visibleWidth = max(screenWidth, 100)

        // Compute aspect ratio scale to fit the route within the visible area
        let scale = max(paddedWidth / visibleWidth, paddedHeight / visibleHeight)

        let targetWidth = screenWidth * scale
        let targetHeight = screenHeight * scale

        // The center of the visible area in screen points
        let visibleCenterY = visibleTop + (visibleHeight / 2)
        // The center of the full screen in screen points
        let screenCenterY = screenHeight / 2

        // Offset required so the route center appears at visibleCenterY instead of screenCenterY
        let deltaYScreen = screenCenterY - visibleCenterY
        let deltaYMap = deltaYScreen * scale

        let targetCenterX = baseRect.midX
        let targetCenterY = baseRect.midY + deltaYMap

        return MKMapRect(
            x: targetCenterX - (targetWidth / 2),
            y: targetCenterY - (targetHeight / 2),
            width: targetWidth,
            height: targetHeight
        )
    }
}

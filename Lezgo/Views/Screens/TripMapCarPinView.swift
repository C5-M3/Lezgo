//
//  TripMapCarPinView.swift
//  Lezgo
//
//  Created by Nathan Sudiara on 26/10/26.
//

import SwiftUI

/// A car on the trip map: its robot, turned the way it drives, with the driver's name under it ("You" under this
/// phone's own car, which also has a blue glow ahead of it, like the location dot in Apple Maps).
///
/// The leader has a crown beside the robot. A stopped car has a pause badge, and an offline car is faded at its last
/// position. The tapped car glows. A car off the route or ahead of the leader has a red ring, a warning badge and a red
/// name.
struct TripMapCarPinView: View {
    let pin: TripMapCarPin
    /// Whether this car's status card is open.
    var isSelected = false
    /// Which way the map is turned, in degrees clockwise from north, so the robot matches the streets.
    var mapHeading: Double = 0
    /// How far the map camera is tilted from straight down, in degrees, so the robot and its ground disc sit in 3D.
    var mapPitch: Double = 60

    /// The robot's image has wide transparent margins, so it is drawn larger than the space it takes.
    private static let imageSize = 114.0
    private static let bodySize = CGSize(width: 64, height: 53)
    /// The whole pin: the robot's turned image, the badges, the crown and the name all fit inside, with the robot in
    /// the middle so it stays on its coordinate. CarPlay's map cuts an annotation off at its frame, so nothing may
    /// reach outside it.
    private static let pinSize = CGSize(width: 130, height: 115)
    private static let depthSlices = 9

    private var headingAngle: Double {
        (pin.course ?? mapHeading) - mapHeading
    }

    private var clampedPitch: Double {
        min(max(mapPitch, 0), 65)
    }

    private var pitchRatio: Double {
        clampedPitch / 60.0
    }

    var body: some View {
        ZStack {
            RoadPuckLayer()
            ExtrudedRobotLayer()
        }
        .frame(width: Self.bodySize.width, height: Self.bodySize.height)
        .overlay(alignment: .topLeading) {
            if let badge = pin.badge {
                BadgeView(badge: badge)
                    .offset(x: -6, y: -6)
            }
        }
        // The crown sits at the top right, as in the hi-fi; the status badge takes the other corner.
        .overlay(alignment: .topTrailing) {
            if pin.isLeader {
                TripMapLeaderCrown()
                    .offset(x: 6, y: -6)
            }
        }
        .overlay(alignment: .bottom) {
            Text(verbatim: pin.label)
                .font(.footnote.weight(.semibold))
                .lineLimit(1)
                .foregroundStyle(pin.isAlerting ? Color.white : Color(.tripCardText))
                .padding(.horizontal, 12)
                .frame(minWidth: 68, maxWidth: 130, minHeight: 22)
                .background(pin.isAlerting ? Color(.formationAlertBackground) : Color(.tripCard), in: .capsule)
                .fixedSize()
                .offset(y: 24)
        }
        .opacity(pin.isOffline ? 0.4 : 1)
        .frame(width: Self.pinSize.width, height: Self.pinSize.height)
        // The pin is a map graphic of a fixed size; bigger text would cover the cars around it.
        // VoiceOver still reads the name and status at any text size, and tapping the car shows its full name.
        .dynamicTypeSize(...DynamicTypeSize.xLarge)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: pin.displayName))
        .accessibilityValue(Text(pin.statuses.formatted(.list(type: .and, width: .narrow))))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    /// The 3D ground disc, drop shadow and headlight beam lying flat on the tilted road surface.
    private func RoadPuckLayer() -> some View {
        ZStack {
            if pin.isMe, pin.course != nil {
                HeadingGlow()
                    .offset(y: -18 * pitchRatio)
            }
            Circle()
                .fill(.black.opacity(0.55))
                .frame(width: 68, height: 68)
                .offset(y: 4)
            Circle()
                .fill(Color(.tripCard).opacity(0.92))
                .frame(width: 62, height: 62)
                .overlay {
                    Circle()
                        .strokeBorder(
                            pin.isAlerting ? Color(.formationAlertBackground) : pin.carColor.color.opacity(0.95),
                            lineWidth: pin.isAlerting ? 4.5 : 3.5
                        )
                }
        }
        .rotationEffect(.degrees(headingAngle))
        .rotation3DEffect(.degrees(clampedPitch), axis: (x: 1, y: 0, z: 0), perspective: 0.45)
        .offset(y: 9 * pitchRatio)
    }

    /// Stacked 3D-tilted slices from the dark lower chassis up to the lit upper dome, giving the robot 3D volume.
    private func ExtrudedRobotLayer() -> some View {
        let image = pin.carColor.TopViewImage(isGlowing: isSelected)
        let bodyPitch = clampedPitch * 0.56
        return ZStack {
            ForEach(0..<Self.depthSlices, id: \.self) { index in
                let fraction = Double(index) / Double(Self.depthSlices - 1)
                let verticalOffset = (6.5 - fraction * 12.5) * pitchRatio
                let scale = 0.91 + sin(fraction * .pi * 0.65) * 0.09
                let shade = -0.32 * (1.0 - fraction)
                Image(image)
                    .resizable()
                    .accessibilityHidden(true)
                    .frame(width: Self.imageSize, height: Self.imageSize)
                    .brightness(shade)
                    .rotationEffect(.degrees(headingAngle))
                    .scaleEffect(scale)
                    .rotation3DEffect(.degrees(bodyPitch), axis: (x: 1, y: 0, z: 0), perspective: 0.45)
                    .offset(y: verticalOffset)
            }
            SphereHighlightOverlay()
                .offset(y: -4 * pitchRatio)
        }
        .shadow(color: .black.opacity(0.5), radius: 3, x: 0, y: 3 * pitchRatio)
    }

    /// Specular top-left highlight and bottom rim shading so the stacked robot reads as a glossy 3D sphere.
    private func SphereHighlightOverlay() -> some View {
        Ellipse()
            .fill(
                RadialGradient(
                    colors: [.white.opacity(0.42), .white.opacity(0.10), .clear, .black.opacity(0.24)],
                    center: UnitPoint(x: 0.36, y: 0.26),
                    startRadius: 2,
                    endRadius: 25
                )
            )
            .frame(width: 44, height: 38)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

extension TripMapCarPinView {
    /// The beam ahead of this phone's own robot, so the driver sees which way they face.
    struct HeadingGlow: View {
        var body: some View {
            Path { path in
                path.move(to: CGPoint(x: 57, y: 50))
                path.addLine(to: CGPoint(x: 16, y: 0))
                path.addQuadCurve(to: CGPoint(x: 98, y: 0), control: CGPoint(x: 57, y: -12))
                path.closeSubpath()
            }
            .fill(LinearGradient(
                colors: [
                    Color(.brandBlue).opacity(0.95),
                    Color(.brandBlue).opacity(0.55),
                    Color(.brandBlue).opacity(0)
                ],
                startPoint: UnitPoint(x: 0.5, y: 0.45),
                endPoint: .top
            ))
            .frame(width: 114, height: 114)
            .accessibilityHidden(true)
        }
    }

    /// A small round badge on the robot's shoulder, on a car alone and on a group card alike.
    struct BadgeView: View {
        let badge: TripMapCarPin.Badge

        var body: some View {
            Image(systemName: badge.symbolName)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(badge == .alert ? Color(.formationAlertBackground) : Color(.tripCard), in: .circle)
                .overlay { Circle().strokeBorder(.white, lineWidth: 1.5) }
                .accessibilityHidden(true)
        }
    }
}

#Preview("Every kind of car") {
    let coordinate = Coordinate(latitude: 0, longitude: 0)
    let pins = [
        ("Budi", MotionState.driving, false, false, false),
        ("Me", .driving, false, true, false),
        ("Agus", .driving, true, false, false),
        ("Dewi", .stopped, false, false, false),
        ("Eka", .driving, false, false, false),
        ("Citra", .stopped, false, false, true)
    ].map { name, motionState, isLeader, isMe, isOffline in
        TripMapCarPin(
            id: UUID(),
            displayName: name,
            coordinate: coordinate,
            motionState: motionState,
            isLeader: isLeader,
            isMe: isMe,
            isOffline: isOffline,
            isAlerting: name == "Eka",
            carColor: .ForMember(atIndex: name.count)
        )
    }
    HStack(spacing: 24) {
        ForEach(pins) { pin in
            TripMapCarPinView(pin: pin, isSelected: pin.displayName == "Budi")
        }
    }
    .padding(40)
    .background(.black)
}

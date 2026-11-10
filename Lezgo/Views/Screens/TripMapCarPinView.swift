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

    /// The robot's image has wide transparent margins, so it is drawn larger than the space it takes.
    private static let imageSize = 114.0
    private static let bodySize = CGSize(width: 64, height: 53)
    /// The whole pin: the robot's turned image, the badges, the crown and the name all fit inside, with the robot in
    /// the middle so it stays on its coordinate. CarPlay's map cuts an annotation off at its frame, so nothing may
    /// reach outside it.
    private static let pinSize = CGSize(width: 130, height: 115)

    var body: some View {
        Image(pin.carColor.TopViewImage(isGlowing: isSelected))
            .resizable()
            .accessibilityHidden(true)
            .frame(width: Self.imageSize, height: Self.imageSize)
            .background {
                if pin.isMe, pin.course != nil {
                    HeadingGlow()
                }
            }
            .rotationEffect(.degrees((pin.course ?? mapHeading) - mapHeading))
            .frame(width: Self.bodySize.width, height: Self.bodySize.height)
            .background {
                if pin.isAlerting {
                    Circle()
                        .strokeBorder(Color(.formationAlertBackground), lineWidth: 4)
                        .frame(width: 62, height: 62)
                }
            }
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
}

extension TripMapCarPinView {
    /// The beam ahead of this phone's own robot, so the driver sees which way they face.
    struct HeadingGlow: View {
        var body: some View {
            Path { path in
                path.move(to: CGPoint(x: 57, y: 57))
                path.addLine(to: CGPoint(x: 35, y: 0))
                path.addQuadCurve(to: CGPoint(x: 79, y: 0), control: CGPoint(x: 57, y: -10))
                path.closeSubpath()
            }
            .fill(LinearGradient(
                colors: [Color(.brandBlue).opacity(0.8), Color(.brandBlue).opacity(0)],
                startPoint: .bottom,
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

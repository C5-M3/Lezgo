//
//  TripMapCarPinView.swift
//  Lezgo
//
//  Created by Nathan Sudiara on 26/10/26.
//

import SwiftUI

/// A car on the trip map: its robot, turned the way it drives, with the driver's name under it.
///
/// The leader has a star. A stopped car has a pause badge, and an offline car is faded at its last position. The
/// tapped car glows. A car off the route or ahead of the leader has a red ring, a warning badge and a red name.
struct TripMapCarPinView: View {
    let pin: TripMapCarPin
    /// Whether this car's status card is open.
    var isSelected = false
    /// Which way the map is turned, in degrees clockwise from north, so the robot matches the streets.
    var mapHeading: Double = 0

    /// The robot's image has wide transparent margins, so it is drawn larger than the space it takes.
    private static let imageSize = 114.0
    private static let bodySize = CGSize(width: 64, height: 53)

    var body: some View {
        Image(RobotImage())
            .resizable()
            .accessibilityHidden(true)
            .frame(width: Self.imageSize, height: Self.imageSize)
            .rotationEffect(.degrees((pin.course ?? mapHeading) - mapHeading))
            .frame(width: Self.bodySize.width, height: Self.bodySize.height)
            .background {
                if pin.isAlerting {
                    Circle()
                        .strokeBorder(Color(.formationAlertBackground), lineWidth: 4)
                        .frame(width: 62, height: 62)
                }
            }
            .overlay(alignment: .topTrailing) {
                if let badge = Badges().first {
                    BadgeView(symbol: badge, isAlert: badge == Self.alertSymbol)
                        .offset(x: 6, y: -6)
                }
            }
            .overlay(alignment: .topLeading) {
                if Badges().count > 1 {
                    let badge = Badges()[1]
                    BadgeView(symbol: badge, isAlert: badge == Self.alertSymbol)
                        .offset(x: -6, y: -6)
                }
            }
            .overlay(alignment: .bottom) {
                Text(verbatim: pin.displayName)
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
            // The pin is a map graphic of a fixed size; bigger text would cover the cars around it.
            // VoiceOver still reads the name and status at any text size, and tapping the car shows its full name.
            .dynamicTypeSize(...DynamicTypeSize.xLarge)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(verbatim: pin.displayName))
            .accessibilityValue(Text(Statuses().formatted(.list(type: .and, width: .narrow))))
            .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private static let alertSymbol = "exclamationmark"

    /// At most two: the first sits at the top right, as in the design, and the second at the top left.
    private func Badges() -> [String] {
        var badges: [String] = []
        if pin.isLeader { badges.append("star.fill") }
        if pin.isAlerting {
            badges.append(Self.alertSymbol)
        } else if pin.motionState == .stopped {
            badges.append("pause.fill")
        }
        return badges
    }

    private func RobotImage() -> ImageResource {
        switch (pin.carColor, isSelected) {
        case (.yellow, false): .ontripNoglowYellow
        case (.yellow, true): .ontripGlowYellow
        case (.purple, false): .ontripNoglowPurple
        case (.purple, true): .ontripGlowPurple
        case (.pink, false): .ontripNoglowPink
        case (.pink, true): .ontripGlowPink
        case (.blue, false): .ontripNoglowBlue
        case (.blue, true): .ontripGlowBlue
        case (.green, false): .ontripNoglowGreen
        case (.green, true): .ontripGlowGreen
        }
    }

    private func Statuses() -> [String] {
        var statuses: [String] = []
        if pin.isMe { statuses.append(String(localized: .tripMapCarYou)) }
        if pin.isLeader { statuses.append(String(localized: .tripMapCarLeader)) }
        if pin.isAlerting { statuses.append(String(localized: .tripMapCarAlert)) }
        if pin.isOffline {
            statuses.append(String(localized: .tripMapCarOffline))
        } else {
            statuses.append(String(localized: pin.motionState == .stopped ? .tripMapCarStopped : .tripMapCarDriving))
        }
        return statuses
    }
}

extension TripMapCarPinView {
    /// A small round badge on the robot's shoulder.
    struct BadgeView: View {
        let symbol: String
        let isAlert: Bool

        var body: some View {
            Image(systemName: symbol)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(isAlert ? Color(.formationAlertBackground) : Color(.tripCard), in: .circle)
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

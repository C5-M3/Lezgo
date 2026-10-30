//
//  TripMapCarPinView.swift
//  Lezgo
//
//  Created by Nathan Sudiara on 26/10/26.
//

import SwiftUI

/// A car on the trip map. My car shows an arrow, the leader a crown, and other cars a car.
/// A stopped car gets a pause badge, and an offline car is faded at its last position. The tapped car has a halo.
/// A car off the route or ahead of the leader gets a red ring and a warning badge. A driving car with a known heading
/// gets a small pointer on its ring, turned the way it drives on the map.
struct TripMapCarPinView: View {
    let pin: TripMapCarPin
    /// Whether this car's status card is open.
    var isSelected = false
    /// Which way the map is turned, in degrees clockwise from north, so the pointer matches the streets.
    var mapHeading: Double = 0

    var body: some View {
        Image(systemName: Symbol())
            .font(.headline)
            .foregroundStyle(pin.motionState == .stopped ? AnyShapeStyle(.secondary) : AnyShapeStyle(.tint))
            .frame(width: 44, height: 44)
            .background(.background, in: .circle)
            .overlay(alignment: .topTrailing) {
                if pin.isAlerting {
                    Circle().strokeBorder(Color(.formationAlertBackground), lineWidth: 4)
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.white, Color(.formationAlertBackground))
                        .accessibilityHidden(true)
                } else {
                    Circle().strokeBorder(.tint, lineWidth: pin.isMe ? 3 : 1)
                }
            }
            .overlay(alignment: .bottomTrailing) {
                if pin.motionState == .stopped {
                    Image(systemName: "pause.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .background(.background, in: .circle)
                        .accessibilityHidden(true)
                }
            }
            .opacity(pin.isOffline ? 0.4 : 1)
            // The pin is a map graphic with a fixed 44 pt circle; a bigger symbol would spill out of it.
            // VoiceOver still reads the name and status at any text size.
            .dynamicTypeSize(...DynamicTypeSize.xLarge)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(verbatim: pin.displayName))
            .accessibilityValue(Text(Statuses().formatted(.list(type: .and, width: .narrow))))
            .accessibilityAddTraits(isSelected ? .isSelected : [])
            .background {
                // The halo around the tapped car, like the focus ring in the lo-fi.
                if isSelected {
                    Circle()
                        .fill(.tint.opacity(0.25))
                        .padding(-10)
                }
            }
            .background {
                if let direction = Direction() {
                    Image(systemName: "arrowtriangle.up.fill")
                        .font(.caption2)
                        .foregroundStyle(.tint)
                        .offset(y: -27)
                        .rotationEffect(direction)
                        .accessibilityHidden(true)
                }
            }
    }

    /// The way a driving car points on screen; a stopped car or one with an unknown heading has none.
    private func Direction() -> Angle? {
        guard pin.motionState == .driving, let course = pin.course else { return nil }
        return .degrees(course - mapHeading)
    }

    private func Symbol() -> String {
        if pin.isMe { return "location.north.fill" }
        if pin.isLeader { return "crown.fill" }
        return "car.fill"
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
            isAlerting: name == "Eka"
        )
    }
    HStack(spacing: 16) {
        ForEach(pins) { pin in
            TripMapCarPinView(pin: pin, isSelected: pin.displayName == "Budi")
        }
    }
    .padding()
}

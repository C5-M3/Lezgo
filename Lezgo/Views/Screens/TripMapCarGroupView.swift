//
//  TripMapCarGroupView.swift
//  Lezgo
//
//  Created by Nathan Sudiara on 05/11/26.
//

import SwiftUI

/// Cars so close together that their robots would overlap, side by side on one dark card with each driver's name
/// under their robot ("You" under this phone's own car). The leader comes first with its crown beside it; a stopped
/// car keeps its pause badge, and a car with an alert keeps its warning badge and red name. A full card counts the
/// other cars; tapping the count opens the card to show them all. Each robot is a button; a tapped car glows in its
/// place while its status is open (`TripMapCarGroup`).
struct TripMapCarGroupView: View {
    let group: TripMapCarGroup
    /// The car whose status card is open, if it is on this card.
    var selectedID: UUID?
    let onSelect: (UUID) -> Void
    /// An opened card of a big group, such as ten cars at the start point, shows every car in rows.
    @State private var isOpen = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let columns = 5
    private static let spacing = 6.0

    var body: some View {
        let pins = group.ShownPins(isOpen: isOpen, selectedID: selectedID)
        Grid(horizontalSpacing: Self.spacing, verticalSpacing: 10) {
            ForEach(Rows(of: pins), id: \.first?.id) { row in
                GridRow {
                    ForEach(row) { pin in
                        RobotButton(pin: pin, isSelected: pin.id == selectedID) { onSelect(pin.id) }
                    }
                    if row.last?.id == pins.last?.id, group.canOpen {
                        CountButton(hiddenCount: group.HiddenCount(isOpen: isOpen), isOpen: isOpen) {
                            isOpen.toggle()
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(Color(.tripCard), in: .rect(cornerRadius: 22))
        // A map graphic of a fixed size; bigger text would cover the cars around it.
        // VoiceOver still reads every name, and tapping a car shows its full name.
        .dynamicTypeSize(...DynamicTypeSize.large)
        .animation(Animation.lezgoPanel.Respecting(reduceMotion: reduceMotion), value: isOpen)
    }

    /// The robots in rows: one row while closed, and rows of `columns` once opened.
    private func Rows(of pins: [TripMapCarPin]) -> [[TripMapCarPin]] {
        stride(from: 0, to: pins.count, by: Self.columns).map { Array(pins[$0..<min($0 + Self.columns, pins.count)]) }
    }
}

extension TripMapCarGroupView {
    /// One car on the card: its robot with the driver's name under it, the crown for the leader at the top left and
    /// the car's status badge at the top right.
    struct RobotButton: View {
        let pin: TripMapCarPin
        let isSelected: Bool
        let action: () -> Void

        /// The robot's image has wide transparent margins, so it is drawn larger than the space it takes.
        private static let imageSize = 78.0
        private static let robotSize = CGSize(width: 46, height: 38)
        private static let depthSlices = 6

        var body: some View {
            Button(action: action) {
                VStack(spacing: 2) {
                    ExtrudedRobot()
                        .frame(width: Self.robotSize.width, height: Self.robotSize.height)
                    Text(verbatim: pin.label)
                        .font(.footnote.weight(.semibold))
                        .lineLimit(1)
                        .foregroundStyle(pin.isAlerting ? Color.white : Color(.tripCardText))
                        .padding(.horizontal, pin.isAlerting ? 6 : 0)
                        .background(pin.isAlerting ? Color(.formationAlertBackground) : Color.clear, in: .capsule)
                        .frame(maxWidth: 58)
                }
                .frame(minWidth: 50, minHeight: 58)
                .opacity(pin.isOffline ? 0.4 : 1)
                .padding(.vertical, 2)
                .background(
                    isSelected ? Color(.tripCardButton) : Color.clear,
                    in: .rect(cornerRadius: 14)
                )
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .overlay(alignment: .topLeading) {
                if pin.isLeader {
                    // Inside the card's padding: CarPlay's map cuts an annotation off at its frame.
                    TripMapLeaderCrown()
                        .offset(x: -8, y: -8)
                }
            }
            .overlay(alignment: .topTrailing) {
                if let badge = pin.badge {
                    TripMapCarPinView.BadgeView(badge: badge)
                        .offset(x: 6, y: -6)
                }
            }
            .accessibilityLabel(Text(verbatim: pin.displayName))
            .accessibilityValue(Text(pin.statuses.formatted(.list(type: .and, width: .narrow))))
            .accessibilityAddTraits(isSelected ? .isSelected : [])
        }

        private func ExtrudedRobot() -> some View {
            let image = pin.carColor.TopViewImage(isGlowing: isSelected)
            return ZStack {
                Ellipse()
                    .fill(Color(.tripCardButton).opacity(0.95))
                    .frame(width: 42, height: 22)
                    .overlay {
                        Ellipse()
                            .strokeBorder(
                                pin.isAlerting ? Color(.formationAlertBackground) : pin.carColor.color.opacity(0.9),
                                lineWidth: 2
                            )
                    }
                    .offset(y: 7)
                ForEach(0..<Self.depthSlices, id: \.self) { index in
                    let fraction = Double(index) / Double(Self.depthSlices - 1)
                    let scale = 0.91 + sin(fraction * .pi * 0.65) * 0.09
                    Image(image)
                        .resizable()
                        .accessibilityHidden(true)
                        .frame(width: Self.imageSize, height: Self.imageSize)
                        .brightness(-0.32 * (1.0 - fraction))
                        .scaleEffect(scale)
                        .rotation3DEffect(.degrees(34), axis: (x: 1, y: 0, z: 0), perspective: 0.45)
                        .offset(y: 4.5 - fraction * 8.5)
                }
                Ellipse()
                    .fill(
                        RadialGradient(
                            colors: [.white.opacity(0.38), .white.opacity(0.08), .clear, .black.opacity(0.22)],
                            center: UnitPoint(x: 0.36, y: 0.26),
                            startRadius: 1,
                            endRadius: 18
                        )
                    )
                    .frame(width: 30, height: 26)
                    .offset(y: -3)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
            .shadow(color: .black.opacity(0.45), radius: 2, x: 0, y: 2)
        }
    }

    /// "+6" on a full card, to open it, and a chevron on an opened card, to close it again.
    struct CountButton: View {
        let hiddenCount: Int
        let isOpen: Bool
        let action: () -> Void

        var body: some View {
            Button(action: action) {
                Group {
                    if isOpen {
                        Image(systemName: "chevron.up")
                            .font(.footnote.weight(.bold))
                    } else {
                        Text(verbatim: "+\(hiddenCount)")
                            .font(.subheadline.weight(.bold))
                    }
                }
                .foregroundStyle(Color(.tripCardText))
                .frame(width: 44, height: 44)
                .background(Color(.tripCardButton), in: .circle)
                .frame(minWidth: 50, minHeight: 58)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isOpen ? Text(.tripMapGroupShowFewer) : Text(.tripMapGroupShowMore(hiddenCount)))
        }
    }
}

#Preview("Two, three and ten cars") {
    let names = ["Agus", "Budi", "Citra", "Dewi", "Eka", "Fajar", "Gita", "Hadi", "Indah", "Joko"]
    let pins = names.enumerated().map { index, name in
        TripMapCarPin(
            id: UUID(),
            displayName: name,
            coordinate: Coordinate(latitude: 0, longitude: 0),
            motionState: index == 3 ? .stopped : .driving,
            isLeader: index == 0,
            isMe: index == 1,
            isOffline: index == 7,
            isAlerting: index == 2,
            carColor: index == 0 ? .yellow : .ForMember(atIndex: index - 1)
        )
    }
    VStack(spacing: 24) {
        TripMapCarGroupView(group: TripMapCarGroup(pins: Array(pins.prefix(2))), onSelect: { _ in })
        TripMapCarGroupView(
            group: TripMapCarGroup(pins: Array(pins.dropFirst().prefix(3))),
            selectedID: pins[2].id,
            onSelect: { _ in }
        )
        TripMapCarGroupView(group: TripMapCarGroup(pins: pins), onSelect: { _ in })
    }
    .padding(32)
    .background(.gray)
}

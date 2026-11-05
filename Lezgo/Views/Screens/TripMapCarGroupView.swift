//
//  TripMapCarGroupView.swift
//  Lezgo
//
//  Created by Nathan Sudiara on 05/11/26.
//

import SwiftUI

/// Cars so close together that their robots would overlap, side by side on one dark card. Each robot is a button, and
/// a tapped car then stands on its own with its status (`TripMapCarGroup`).
struct TripMapCarGroupView: View {
    let group: TripMapCarGroup
    let onSelect: (UUID) -> Void

    /// The most robots that fit on the map without covering it. The rest are counted.
    private static let maxRobots = 4
    /// The robot's image has wide transparent margins, so it is drawn larger than the space it takes.
    private static let imageSize = 114.0
    private static let robotSize = CGSize(width: 64, height: 53)

    var body: some View {
        HStack(spacing: group.pins.count > 2 ? -12 : 9) {
            ForEach(group.pins.prefix(Self.maxRobots)) { pin in
                Button { onSelect(pin.id) } label: {
                    Image(pin.carColor.TopViewImage(isGlowing: false))
                        .resizable()
                        .accessibilityHidden(true)
                        .frame(width: Self.imageSize, height: Self.imageSize)
                        .frame(width: Self.robotSize.width, height: Self.robotSize.height)
                        .opacity(pin.isOffline ? 0.4 : 1)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(verbatim: pin.displayName))
            }
            if group.pins.count > Self.maxRobots {
                Text(verbatim: "+\(group.pins.count - Self.maxRobots)")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding(.leading, 18)
            }
        }
        .padding(.horizontal, 20)
        .frame(minHeight: 76)
        .background(.black, in: .rect(cornerRadius: 27))
        // A map graphic of a fixed size; bigger text would cover the cars around it.
        .dynamicTypeSize(...DynamicTypeSize.xLarge)
    }
}

#Preview("Two, three and six cars") {
    let colors: [TripMapCarPin.CarColor] = [.yellow, .purple, .pink, .blue, .green, .purple]
    let pins = colors.enumerated().map { index, color in
        TripMapCarPin(
            id: UUID(),
            displayName: "Car \(index)",
            coordinate: Coordinate(latitude: 0, longitude: 0),
            motionState: .driving,
            isLeader: false,
            isMe: false,
            isOffline: false,
            carColor: color
        )
    }
    VStack(spacing: 16) {
        TripMapCarGroupView(group: TripMapCarGroup(pins: Array(pins.prefix(2))), onSelect: { _ in })
        TripMapCarGroupView(group: TripMapCarGroup(pins: Array(pins.prefix(3))), onSelect: { _ in })
        TripMapCarGroupView(group: TripMapCarGroup(pins: pins), onSelect: { _ in })
    }
    .padding()
}

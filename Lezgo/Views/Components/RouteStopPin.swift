//
//  RouteStopPin.swift
//  Lezgo
//
//  Created by Nathan Sudiara on 09/11/26.
//

import SwiftUI

/// A stop on a route map, drawn as in the hi-fi: the destination is a yellow circle with a checkered flag, a stop on
/// the way is a white circle with a pin, and the start is a dark circle with the house used in the route lists.
/// The planners draw the leader's robot at the start instead, so `.start` is only for the trip map.
struct RouteStopPin: View {
    let kind: WaypointKind

    var body: some View {
        Group {
            switch kind {
            case .destination:
                Image(systemName: "flag.checkered")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(Color(.tripCard))
                    .frame(width: 44, height: 44)
                    .background(Color(.brandYellow), in: .circle)
                    .accessibilityHidden(true)
            case .checkpoint:
                Image(systemName: "mappin.circle.fill")
                    .font(.title3)
                    .foregroundStyle(Color(.tripCard))
                    .frame(width: 34, height: 34)
                    .background(Color(.tripCardText), in: .circle)
                    .overlay { Circle().strokeBorder(Color(.tripCard), lineWidth: 3) }
                    .accessibilityHidden(true)
            case .start:
                Image(systemName: "house.fill")
                    .font(.headline)
                    .foregroundStyle(Color(.brandYellow))
                    .frame(width: 34, height: 34)
                    .background(Color(.tripCard), in: .circle)
                    .accessibilityHidden(true)
            }
        }
        .shadow(color: .black.opacity(0.3), radius: 3, y: 1)
        // A map graphic of a fixed size: bigger text would make the symbol leave its circle.
        .dynamicTypeSize(...DynamicTypeSize.large)
        .accessibilityHidden(true)
    }
}

#Preview("Every kind") {
    HStack(spacing: 16) {
        RouteStopPin(kind: .start)
        RouteStopPin(kind: .checkpoint)
        RouteStopPin(kind: .destination)
    }
    .padding()
    .background(.gray)
}

//
//  TripMapCompass.swift
//  Lezgo
//
//  Created by Nathan Sudiara on 10/11/26.
//

import SwiftUI

/// The trip map's compass, in place of Apple's Liquid Glass one: a dark round button like the other map buttons,
/// with an "N" and a yellow pointer that turn to show north. It shows only while the map is turned away from north,
/// and a tap turns the map back to north.
struct TripMapCompass: View {
    let heading: TripMapHeading

    var body: some View {
        ZStack {
            if heading.isTurned {
                Button(action: heading.PointNorth) {
                    // "N" under a yellow pointer, like a compass, so it never reads as the arrow that follows my car.
                    VStack(spacing: -2) {
                        Image(systemName: "arrowtriangle.up.fill")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Color(.brandYellow))
                        Text(verbatim: "N")
                            .font(.headline.weight(.heavy))
                    }
                    .rotationEffect(.degrees(-heading.degrees))
                }
                .buttonStyle(TripMapCameraControls.RoundStyle())
                .accessibilityLabel(Text(.tripMapPointNorth))
                .transition(.opacity)
            }
        }
        .animation(.lezgoFade, value: heading.isTurned)
    }
}

#Preview("Turned") {
    let heading = TripMapHeading()
    heading.Update(40)
    return TripMapCompass(heading: heading)
        .padding()
        .background(.gray)
}

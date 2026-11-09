//
//  TripMapCardButtonStyle.swift
//  Lezgo
//
//  Created by Nathan Sudiara on 05/11/26.
//

import SwiftUI

/// The big rounded button inside the trip map's bottom card: Edit Route, New Destination, and End Trip or Exit Trip.
struct TripMapCardButtonStyle: ButtonStyle {
    /// The yellow version, for the one thing the driver is expected to do next.
    var isProminent = false

    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, minHeight: 56)
            .padding(.horizontal)
            .foregroundStyle(isProminent ? AnyShapeStyle(Color(.tripCard)) : AnyShapeStyle(.foreground))
            .background(isProminent ? Color(.brandYellow) : Color(.tripCardButton), in: .capsule)
            .contentShape(.capsule)
            .opacity(isEnabled ? (configuration.isPressed ? 0.7 : 1) : 0.5)
    }
}

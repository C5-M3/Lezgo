//
//  TripMapView+ConnectionLostNotice.swift
//  Lezgo
//
//  Created by Nathan Sudiara on 26/10/26.
//

import SwiftUI

extension TripMapView {
    /// A quiet notice under the turn card while this phone cannot send its position (#220). It is not an alert:
    /// the driver needs no action, and it goes away by itself when the connection is back.
    struct ConnectionLostNotice: View {
        var body: some View {
            Label(.tripMapConnectionLost, systemImage: "wifi.slash")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color(.tripCardText))
                .padding(.horizontal)
                .padding(.vertical, 8)
                // A dark capsule like the other trip map cards, instead of Liquid Glass.
                .background(Color(.tripCard), in: .capsule)
                .accessibilityAddTraits(.isStaticText)
        }
    }
}

#Preview("Connection lost") {
    TripMapView.ConnectionLostNotice()
        .padding()
}

//
//  SiriCarAvatar.swift
//  Lezgo
//
//  Created by Nathan Sudiara on 12/11/26.
//

import SwiftUI

/// A car's robot in a dark circle on a Siri card (US-08), with a crown for the leader, as on the trip map.
struct SiriCarAvatar: View {
    let color: TripMapCarPin.CarColor
    var isLeader = false
    var hasArrived = false
    var size: CGFloat = 44

    var body: some View {
        Image(color.frontImage)
            .resizable()
            .scaledToFit()
            .padding(size * 0.1)
            .frame(width: size, height: size)
            .background(Color(.tripCard), in: .circle)
            .overlay(alignment: .topTrailing) {
                if isLeader {
                    Image(systemName: "crown.fill")
                        .font(.caption)
                        .foregroundStyle(.yellow)
                        .offset(x: 4, y: -4)
                }
            }
            .overlay(alignment: .bottomTrailing) {
                if hasArrived {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.body)
                        .symbolRenderingMode(.multicolor)
                        .foregroundStyle(.white, .green)
                        .offset(x: 3, y: 3)
                }
            }
            .accessibilityHidden(true)
    }
}

#Preview {
    HStack {
        SiriCarAvatar(color: .yellow, isLeader: true)
        SiriCarAvatar(color: .blue, hasArrived: true)
        SiriCarAvatar(color: .pink, size: 56)
    }
    .padding()
}

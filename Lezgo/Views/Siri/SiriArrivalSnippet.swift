//
//  SiriArrivalSnippet.swift
//  Lezgo
//
//  Created by Nathan Sudiara on 12/11/26.
//

import SwiftUI

/// Siri's card while it asks "Arrived at …?" (US-08): the destination and how far its point is.
struct SiriArrivalSnippet: View {
    let confirmation: TripMapManualArrival.Confirmation

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "flag.checkered")
                .font(.title3.bold())
                .foregroundStyle(Color(.brandYellow))
                .frame(width: 44, height: 44)
                .background(Color(.tripCard), in: .circle)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(confirmation.destinationName)
                    .font(.headline)
                    .lineLimit(2)
                Text(.siriFromDestinationPoint(
                    confirmation.distance.formatted(.measurement(width: .abbreviated, usage: .asProvided))
                ))
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
        .padding()
    }
}

#Preview {
    SiriArrivalSnippet(confirmation: .init(
        destinationID: UUID(),
        destinationName: "Pantai Parangtritis",
        distance: Measurement(value: 200, unit: .meters)
    ))
    .padding()
}

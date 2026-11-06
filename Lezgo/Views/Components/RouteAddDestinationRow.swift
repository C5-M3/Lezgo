//
//  RouteAddDestinationRow.swift
//  Lezgo
//
//  Created by Farrell Sudjatmiko on 06/11/26.
//

import SwiftUI

struct RouteAddDestinationRow: View {
    let onAddDestination: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Divider()
                .overlay(Color(white: 0.22))

            Button(action: onAddDestination) {
                HStack(spacing: 12) {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.heroYellow)
                        .frame(width: 24, height: 24)
                        .accessibilityHidden(true)

                    Text("Add Destination")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Color.heroYellow)

                    Spacer()
                }
                .frame(minHeight: 28)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }
}

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
        VStack(spacing: 0) {
            Divider()
                .overlay(Color(white: 0.22))
                .padding(.bottom, 12)

            Button(action: onAddDestination) {
                HStack(spacing: 12) {
                    Image(systemName: "plus")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Color.heroYellow)
                        .frame(width: 24, height: 24)
                        .accessibilityHidden(true)

                    Text("Add Destination")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Color.heroYellow)

                    Spacer()
                }
                .frame(height: 36)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }
}

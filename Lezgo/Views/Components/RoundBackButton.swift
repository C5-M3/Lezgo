//
//  RoundBackButton.swift
//  Lezgo
//
//  Created by Nathan Sudiara on 16/11/26.
//

import SwiftUI

/// The round dark Back button at the top left of the route planner and of Enter room code.
struct RoundBackButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Circle()
                .fill(Color(white: 0.16).opacity(0.92))
                .frame(width: 40, height: 40)
                .overlay {
                    Image(systemName: "chevron.left")
                        .font(.callout.weight(.bold))
                        .foregroundStyle(.white)
                        .accessibilityHidden(true)
                }
                // A 44-point target around the 40-point circle.
                .frame(width: 44, height: 44)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        // The arrow sits in a circle of a fixed size, so it stops growing before it would not fit.
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        .accessibilityLabel("Back")
    }
}

#Preview {
    RoundBackButton {}
        .padding()
        .background(Color(.tripCard))
}

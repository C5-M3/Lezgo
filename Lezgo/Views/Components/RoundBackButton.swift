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
        Button("Back", systemImage: "chevron.left", action: action)
            .labelStyle(.iconOnly)
            .font(.callout.weight(.bold))
            .lezgoGlassButton(.round)
    }
}

#Preview {
    RoundBackButton {}
        .padding()
        .background(Color(.tripCard))
}

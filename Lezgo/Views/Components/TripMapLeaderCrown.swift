//
//  TripMapLeaderCrown.swift
//  Lezgo
//
//  Created by Nathan Sudiara on 06/11/26.
//

import SwiftUI

/// The leader's crown beside the leader's robot on the trip map, the same crown as in the Trip Room.
struct TripMapLeaderCrown: View {
    var body: some View {
        Image(systemName: "crown.fill")
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(Color(.brandYellow))
            .frame(width: 22, height: 22)
            .background(Color(.tripCard), in: .circle)
            .overlay { Circle().strokeBorder(Color(.brandYellow).opacity(0.35), lineWidth: 1) }
            .accessibilityHidden(true)
    }
}

#Preview {
    TripMapLeaderCrown()
        .padding()
        .background(.gray)
}

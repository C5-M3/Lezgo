//
//  TripActivitySmallView.swift
//  LezgoWidgets
//
//  Created by Nathan Sudiara on 12/11/26.
//

import SwiftUI

/// The trip on the CarPlay dashboard and in Apple Watch's Smart Stack, where iOS gives a small tile: your robot,
/// where the group is going next, the time, and the leg.
struct TripActivitySmallView: View {
    let state: TripActivityAttributes.ContentState

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                TripActivityRobotHead(color: state.myColor, size: 22)
                Text(state.title)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
            }
            TripActivityTime(state: state, size: 22)
            TripActivityLegRoad(state: state, robotSize: 20)
        }
        .padding(10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .foregroundStyle(.white)
        .background(Color(.tripCard))
    }
}

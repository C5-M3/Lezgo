//
//  RouteConnectingLine.swift
//  Lezgo
//
//  Created by Farrell Sudjatmiko on 06/11/26.
//

import SwiftUI

struct RouteConnectingLine: View {
    var body: some View {
        HStack(spacing: 0) {
            Rectangle()
                .fill(Color.heroYellow.opacity(0.85))
                .frame(width: 1.5, height: 16)
                .padding(.leading, 11.25)
            Spacer()
        }
    }
}

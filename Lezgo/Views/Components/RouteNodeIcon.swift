//
//  RouteNodeIcon.swift
//  Lezgo
//
//  Created by Farrell Sudjatmiko on 06/11/26.
//

import SwiftUI

enum RouteNodeLineStyle {
    case start
    case middle
    case end
    case none
}

struct RouteNodeIcon: View {
    let systemName: String
    let color: Color
    let lineStyle: RouteNodeLineStyle

    var body: some View {
        ZStack {
            connectingLine
            iconGlyph
        }
        .frame(width: 24, height: 44)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var connectingLine: some View {
        switch lineStyle {
        case .start:
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                Rectangle()
                    .fill(Color.heroYellow.opacity(0.85))
                    .frame(width: 1.5, height: 22)
            }
        case .middle:
            VStack(spacing: 0) {
                Rectangle()
                    .fill(Color.heroYellow.opacity(0.85))
                    .frame(width: 1.5)
            }
        case .end:
            VStack(spacing: 0) {
                Rectangle()
                    .fill(Color.heroYellow.opacity(0.85))
                    .frame(width: 1.5, height: 22)
                Spacer(minLength: 0)
            }
        case .none:
            EmptyView()
        }
    }

    private var iconGlyph: some View {
        Image(systemName: systemName)
            .font(.system(size: 16))
            .foregroundStyle(color)
            .frame(width: 24, height: 24)
            .accessibilityHidden(true)
            .background(
                Circle()
                    .fill(Color(red: 26 / 255, green: 26 / 255, blue: 28 / 255))
                    .frame(width: 20, height: 20)
            )
    }
}

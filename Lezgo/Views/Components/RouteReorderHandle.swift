//
//  RouteReorderHandle.swift
//  Lezgo
//
//  Created by Farrell Sudjatmiko on 06/11/26.
//

import SwiftUI

struct RouteReorderHandle: View {
    let id: String
    let name: String
    let iconName: String
    let index: Int
    let count: Int
    let onMove: (Int, Int) -> Void

    var body: some View {
        Image(systemName: "line.3.horizontal")
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(Color(white: 0.45))
            .frame(width: 36, height: 36)
            .contentShape(Rectangle())
            .accessibilityLabel("Reorder")
            .draggable(id) {
                dragPreview
            }
    }

    private var dragPreview: some View {
        HStack(spacing: 12) {
            Image(systemName: iconName)
                .font(.system(size: 16))
                .foregroundStyle(Color.heroYellow)
                .frame(width: 24, height: 24)
                .accessibilityHidden(true)

            Text(name)
                .font(.system(size: 17))
                .foregroundStyle(.white)
                .lineLimit(1)

            Spacer()

            Image(systemName: "line.3.horizontal")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.heroYellow)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(width: 280)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(red: 32 / 255, green: 32 / 255, blue: 34 / 255))
                .shadow(color: .black.opacity(0.4), radius: 8, x: 0, y: 4)
        )
    }
}

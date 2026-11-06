//
//  RouteReorderHandle.swift
//  Lezgo
//
//  Created by Farrell Sudjatmiko on 06/11/26.
//

import SwiftUI

struct RouteReorderHandle: View {
    let index: Int
    let count: Int
    let onMove: (Int, Int) -> Void

    var body: some View {
        Image(systemName: "line.3.horizontal")
            .font(.system(size: 14))
            .foregroundStyle(Color(white: 0.35))
            .frame(width: 28, height: 28)
            .contentShape(Rectangle())
            .accessibilityLabel("Reorder")
            .gesture(
                DragGesture(minimumDistance: 12, coordinateSpace: .global)
                    .onChanged { value in
                        let deltaY = value.translation.height
                        if deltaY < -34 && index > 0 {
                            onMove(index, index - 1)
                        } else if deltaY > 34 && index < count - 1 {
                            onMove(index, index + 2)
                        }
                    }
            )
    }
}

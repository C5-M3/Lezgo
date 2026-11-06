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

    @State private var dragAccumulator: CGFloat = 0
    @State private var isDragging: Bool = false

    var body: some View {
        Image(systemName: "line.3.horizontal")
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(isDragging ? Color.heroYellow : Color(white: 0.45))
            .frame(width: 36, height: 36)
            .contentShape(Rectangle())
            .accessibilityLabel("Reorder")
            .highPriorityGesture(
                DragGesture(minimumDistance: 1, coordinateSpace: .global)
                    .onChanged { value in
                        isDragging = true
                        let delta = value.translation.height - dragAccumulator
                        let threshold: CGFloat = 34

                        if delta < -threshold && index > 0 {
                            dragAccumulator = value.translation.height
                            onMove(index, index - 1)
                        } else if delta > threshold && index < count - 1 {
                            dragAccumulator = value.translation.height
                            onMove(index, index + 2)
                        }
                    }
                    .onEnded { _ in
                        isDragging = false
                        dragAccumulator = 0
                    }
            )
    }
}

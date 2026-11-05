//
//  RoutePlanCard+DragDrop.swift
//  Lezgo
//
//  Created by Farrell Sudjatmiko on 05/11/26.
//

import SwiftUI

struct DestinationDragDropModifier: ViewModifier {
    let lastPoint: RoutePoint?
    let lastIndex: Int?
    let destinations: [RoutePoint]
    let onMoveDestination: ((IndexSet, Int) -> Void)?

    func body(content: Content) -> some View {
        if let lastPoint = lastPoint, let lastIndex = lastIndex, destinations.count > 1 {
            content
                .draggable(lastPoint.id.uuidString)
                .dropDestination(for: String.self) { items, _ in
                    guard let draggedID = items.first,
                          let fromIndex = destinations.firstIndex(where: { $0.id.uuidString == draggedID }),
                          fromIndex != lastIndex else {
                        return false
                    }
                    withAnimation {
                        onMoveDestination?(
                            IndexSet(integer: fromIndex),
                            lastIndex > fromIndex ? lastIndex + 1 : lastIndex
                        )
                    }
                    return true
                }
        } else {
            content
        }
    }
}

struct StopDragDropModifier: ViewModifier {
    let stop: RoutePoint
    let index: Int
    let destinations: [RoutePoint]
    let onMoveDestination: ((IndexSet, Int) -> Void)?

    func body(content: Content) -> some View {
        content
            .draggable(stop.id.uuidString)
            .dropDestination(for: String.self) { items, _ in
                guard let draggedID = items.first,
                      let fromIndex = destinations.firstIndex(where: { $0.id.uuidString == draggedID }),
                      fromIndex != index else {
                    return false
                }
                withAnimation {
                    onMoveDestination?(
                        IndexSet(integer: fromIndex),
                        index > fromIndex ? index + 1 : index
                    )
                }
                return true
            }
    }
}

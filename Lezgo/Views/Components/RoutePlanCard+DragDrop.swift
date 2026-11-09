//
//  RoutePlanCard+DragDrop.swift
//  Lezgo
//
//  Created by Farrell Sudjatmiko on 05/11/26.
//

import SwiftUI

struct PointDragDropModifier: ViewModifier {
    let point: RoutePoint?
    let index: Int?
    let destinations: [RoutePoint]
    let onMoveDestination: ((IndexSet, Int) -> Void)?

    func body(content: Content) -> some View {
        if let point = point, let index = index, destinations.count > 1 {
            content
                .draggable(point.id.uuidString)
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
        } else {
            content
        }
    }
}

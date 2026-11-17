//
//  RouteTooFarDialog.swift
//  Lezgo
//

import SwiftUI

/// Tells the person that no road leads from the start point through the stops, and offers to edit the point they
/// changed last (`specs/UserStories.md` → US-01). Set Route and the route sheet on the map share it.
struct RouteTooFarDialog: ViewModifier {
    let viewModel: MapViewModel

    func body(content: Content) -> some View {
        content.confirmDialog(
            isPresented: Binding(
                get: { viewModel.isRouteTooFar },
                set: { viewModel.isRouteTooFar = $0 }
            ),
            title: Text(.setRouteTooFarTitle),
            message: Text(.setRouteTooFarMessage),
            cancelTitle: nil,
            confirmTitle: viewModel.lastEditedPoint == .start
                ? .setRouteTooFarEditStart
                : .setRouteTooFarEditDestination,
            onConfirm: viewModel.EditTooFarPoint
        )
    }
}

extension View {
    /// Shows the "too far" dialog while `viewModel.isRouteTooFar` is true.
    func routeTooFarDialog(viewModel: MapViewModel) -> some View {
        modifier(RouteTooFarDialog(viewModel: viewModel))
    }
}

#if DEBUG
#Preview("Edit Destination") {
    let viewModel = MapViewModel()
    viewModel.isRouteTooFar = true
    return Color.black.routeTooFarDialog(viewModel: viewModel)
}

#Preview("Edit Start") {
    let viewModel = MapViewModel()
    viewModel.lastEditedPoint = .start
    viewModel.isRouteTooFar = true
    return Color.black.routeTooFarDialog(viewModel: viewModel)
}
#endif

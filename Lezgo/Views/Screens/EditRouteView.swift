//
//  EditRouteView.swift
//  Lezgo
//
//  Created by Nathan Sudiara on 29/10/26.
//

import SwiftUI

/// Edit Route (`specs/UserStories.md` → US-06, "Route changes"): the Set Route planner opened on the road, from the
/// leader's position through what is left of the route. Save sends the changed route to every phone.
struct EditRouteView: View {
    let viewModel: EditRouteViewModel
    let onClose: () -> Void
    @State private var planner: MapViewModel

    init(viewModel: EditRouteViewModel, onClose: @escaping () -> Void) {
        self.viewModel = viewModel
        self.onClose = onClose
        _planner = State(initialValue: MapViewModel(startingWaypoints: viewModel.startingWaypoints))
    }

    var body: some View {
        SetRouteMapView(
            viewModel: planner,
            title: .editRouteTitle,
            nextTitle: .editRouteSave,
            onBack: onClose,
            onNext: Save,
            // Back while saving would leave a save running with no screen to show its result.
            isBackDisabled: viewModel.isSaving,
            // Nothing to save until the road path for the current stops is ready.
            isNextDisabled: viewModel.isSaving || planner.MakeTripPlan() == nil,
            isStartPointLocked: true
        )
        // The planner only finds a road path once a stop changes, so the route it opens with needs one too.
        .task { planner.findRoute() }
        .onChange(of: viewModel.didSave) {
            if viewModel.didSave { onClose() }
        }
        .onChange(of: viewModel.errorMessage) {
            // Shown by the planner's own alert, which sits above its sheet.
            if let message = viewModel.errorMessage { planner.errorMessage = message }
        }
        .onChange(of: planner.errorMessage) {
            if planner.errorMessage == nil { viewModel.DismissError() }
        }
    }

    /// Saves the route on the map; Save stays disabled until there is one.
    private func Save() {
        guard let plan = planner.MakeTripPlan() else { return }
        Task { await viewModel.Save(plan) }
    }
}

#if DEBUG
#Preview {
    EditRouteView(
        viewModel: EditRouteViewModel(
            startingWaypoints: [.CurrentLocation(at: SampleTrip.plan.waypoints[0].coordinate)]
                + SampleTrip.plan.waypoints.dropFirst(),
            tripID: SampleTrip.tripID,
            myParticipantID: SampleTrip.agusID,
            tripService: SampleTrip.Service(status: .inTrip, me: SampleTrip.agusID)
        ),
        onClose: {}
    )
}
#endif

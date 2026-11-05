//
//  TripRoomAlertsModifier.swift
//  Lezgo
//
//  Created by Oky Faishal on 27/10/26.
//

import SwiftUI

/// The Trip Room's alerts: leaving, being removed, the leader ending the trip, and errors. "Start Trip?" is
/// `StartTripDialog`, and Kick and Set Lead ask inside Edit Profile.
struct TripRoomAlertsModifier: ViewModifier {
    let viewModel: TripRoomViewModel
    @Binding var showingLeave: Bool
    let dismissAction: () -> Void

    func body(content: Content) -> some View {
        content
            .leaveAlert(viewModel: viewModel, isPresented: $showingLeave, dismissAction: dismissAction)
            .removedAlert(viewModel: viewModel, dismissAction: dismissAction)
            .endedByLeaderAlert(viewModel: viewModel, dismissAction: dismissAction)
            .errorAlert(viewModel: viewModel)
    }
}

// MARK: - Alert View Extensions

private extension View {
    /// Exit asks first; the room closes only once leaving succeeded (`specs/UserStories.md` → US-07).
    func leaveAlert(
        viewModel: TripRoomViewModel,
        isPresented: Binding<Bool>,
        dismissAction: @escaping () -> Void
    ) -> some View {
        let isEndingForEveryone = viewModel.leaveConfirmation == .endTripForEveryone
        return alert(
            Text(isEndingForEveryone ? .tripRoomExitAndEndTripQuestion : .tripRoomExitRoomQuestion),
            isPresented: isPresented
        ) {
            Button(role: .cancel) { } label: { Text(.tripRoomCancel) }
            Button(role: isEndingForEveryone ? .destructive : nil) {
                Task {
                    do {
                        try await viewModel.LeaveTrip()
                        if viewModel.hasLeft { dismissAction() }
                    } catch {
                        viewModel.ShowError(error)
                    }
                }
            } label: {
                Text(.tripRoomConfirm)
            }
        }
    }

    func removedAlert(viewModel: TripRoomViewModel, dismissAction: @escaping () -> Void) -> some View {
        alert(
            "You were removed from the trip.",
            isPresented: Binding(
                get: { viewModel.wasRemovedFromTrip },
                set: { viewModel.wasRemovedFromTrip = $0 }
            )
        ) {
            Button("OK") { dismissAction() }
        }
    }

    /// A member whose leader left the room returns to Home; the trip is already cleared from the phone (US-07).
    func endedByLeaderAlert(viewModel: TripRoomViewModel, dismissAction: @escaping () -> Void) -> some View {
        alert(
            Text(.tripRoomLeaderEndedTrip),
            isPresented: Binding(
                get: { viewModel.wasEndedByLeader },
                set: { viewModel.wasEndedByLeader = $0 }
            )
        ) {
            Button { dismissAction() } label: { Text(.tripRoomOK) }
        }
    }

    func errorAlert(viewModel: TripRoomViewModel) -> some View {
        alert(
            "Error",
            isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )
        ) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            if let msg = viewModel.errorMessage {
                Text(msg)
            }
        }
    }
}

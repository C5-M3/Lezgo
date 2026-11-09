//
//  TripRoomAlertsModifier.swift
//  Lezgo
//
//  Created by Oky Faishal on 27/10/26.
//

import SwiftUI

/// The Trip Room's confirmations and messages: leaving, being removed, the leader ending the trip, and errors. They
/// all use the shared `ConfirmDialog`. "Start Trip?" and the questions for a held avatar are in `TripRoomView`.
struct TripRoomAlertsModifier: ViewModifier {
    let viewModel: TripRoomViewModel
    @Binding var showingLeave: Bool
    /// The car the leader chose in the menu of a held avatar; the dialog is open while it is set.
    @Binding var participantToRemove: Participant?
    @Binding var participantToMakeLeader: Participant?
    let dismissAction: () -> Void

    func body(content: Content) -> some View {
        content
            .removeAlert(viewModel: viewModel, participant: $participantToRemove)
            .setLeaderAlert(viewModel: viewModel, participant: $participantToMakeLeader)
            .leaveAlert(viewModel: viewModel, isPresented: $showingLeave, dismissAction: dismissAction)
            .removedAlert(viewModel: viewModel, dismissAction: dismissAction)
            .endedByLeaderAlert(viewModel: viewModel, dismissAction: dismissAction)
            .errorAlert(viewModel: viewModel)
    }
}

// MARK: - Dialog View Extensions

private extension Binding where Value == Participant? {
    /// `true` while a car is chosen; closing the dialog clears it.
    var isSet: Binding<Bool> {
        Binding<Bool>(get: { wrappedValue != nil }, set: { if !$0 { wrappedValue = nil } })
    }
}

private extension View {
    /// "Remove XX from the trip?" (US-05).
    func removeAlert(viewModel: TripRoomViewModel, participant: Binding<Participant?>) -> some View {
        confirmDialog(
            isPresented: participant.isSet,
            title: Text(verbatim: participant.wrappedValue.map(viewModel.RemoveParticipantConfirmationTitle) ?? ""),
            confirmTitle: LocalizedStringResource("Remove"),
            onConfirm: {
                guard let removed = participant.wrappedValue else { return }
                Task { await viewModel.RemoveFromTrip(removed) }
            }
        )
    }

    /// "Set XX as Trip Leader?" (US-05).
    func setLeaderAlert(viewModel: TripRoomViewModel, participant: Binding<Participant?>) -> some View {
        confirmDialog(
            isPresented: participant.isSet,
            title: Text(verbatim: participant.wrappedValue.map(viewModel.SetLeaderConfirmationTitle) ?? ""),
            onConfirm: {
                guard let newLeader = participant.wrappedValue else { return }
                Task { await viewModel.HandOverLead(to: newLeader) }
            }
        )
    }

    /// Exit asks first; the room closes only once leaving succeeded (`specs/UserStories.md` → US-07).
    func leaveAlert(
        viewModel: TripRoomViewModel,
        isPresented: Binding<Bool>,
        dismissAction: @escaping () -> Void
    ) -> some View {
        let isEndingForEveryone = viewModel.leaveConfirmation == .endTripForEveryone
        return confirmDialog(
            isPresented: isPresented,
            title: Text(isEndingForEveryone ? .tripRoomExitAndEndTripQuestion : .tripRoomExitRoomQuestion),
            onConfirm: {
                Task {
                    do {
                        try await viewModel.LeaveTrip()
                        if viewModel.hasLeft { dismissAction() }
                    } catch {
                        viewModel.ShowError(error)
                    }
                }
            }
        )
    }

    func removedAlert(viewModel: TripRoomViewModel, dismissAction: @escaping () -> Void) -> some View {
        confirmDialog(
            isPresented: Binding(
                get: { viewModel.wasRemovedFromTrip },
                set: { viewModel.wasRemovedFromTrip = $0 }
            ),
            title: Text("You were removed from the trip."),
            cancelTitle: nil,
            confirmTitle: .tripRoomOK,
            onConfirm: dismissAction
        )
    }

    /// A member whose leader left the room returns to Home; the trip is already cleared from the phone (US-07).
    func endedByLeaderAlert(viewModel: TripRoomViewModel, dismissAction: @escaping () -> Void) -> some View {
        confirmDialog(
            isPresented: Binding(
                get: { viewModel.wasEndedByLeader },
                set: { viewModel.wasEndedByLeader = $0 }
            ),
            title: Text(.tripRoomLeaderEndedTrip),
            cancelTitle: nil,
            confirmTitle: .tripRoomOK,
            onConfirm: dismissAction
        )
    }

    func errorAlert(viewModel: TripRoomViewModel) -> some View {
        confirmDialog(
            isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            ),
            title: Text("Error"),
            message: viewModel.errorMessage.map { Text(verbatim: $0) },
            cancelTitle: nil,
            confirmTitle: .tripRoomOK,
            onConfirm: { viewModel.errorMessage = nil }
        )
    }
}

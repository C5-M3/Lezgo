//
//  TripRoomAlertsModifier.swift
//  Lezgo
//
//  Created by Oky Faishal on 27/10/26.
//

import SwiftUI

struct TripRoomAlertsModifier: ViewModifier {
    let viewModel: TripRoomViewModel
    @Binding var showingLeave: Bool
    @Binding var showingStart: Bool
    @Binding var showingRemove: Bool
    @Binding var participantToKick: Participant?
    @Binding var participantToSetLeader: Participant?
    let dismissAction: () -> Void

    func body(content: Content) -> some View {
        content
            .modifier(TripLifecycleAlertsModifier(
                viewModel: viewModel,
                showingLeave: $showingLeave,
                showingStart: $showingStart,
                dismissAction: dismissAction
            ))
            .modifier(ParticipantManagementAlertsModifier(
                viewModel: viewModel,
                showingRemove: $showingRemove,
                participantToKick: $participantToKick,
                participantToSetLeader: $participantToSetLeader
            ))
    }
}

private struct TripLifecycleAlertsModifier: ViewModifier {
    let viewModel: TripRoomViewModel
    @Binding var showingLeave: Bool
    @Binding var showingStart: Bool
    let dismissAction: () -> Void

    func body(content: Content) -> some View {
        content
            .leaveAlert(viewModel: viewModel, isPresented: $showingLeave, dismissAction: dismissAction)
            .startAlert(viewModel: viewModel, isPresented: $showingStart)
            .removedAlert(viewModel: viewModel, dismissAction: dismissAction)
            .errorAlert(viewModel: viewModel)
    }
}

private struct ParticipantManagementAlertsModifier: ViewModifier {
    let viewModel: TripRoomViewModel
    @Binding var showingRemove: Bool
    @Binding var participantToKick: Participant?
    @Binding var participantToSetLeader: Participant?

    func body(content: Content) -> some View {
        content
            .removeMultipleAlert(viewModel: viewModel, isPresented: $showingRemove)
            .kickAlert(viewModel: viewModel, target: $participantToKick)
            .setLeaderAlert(viewModel: viewModel, target: $participantToSetLeader)
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

    func startAlert(viewModel: TripRoomViewModel, isPresented: Binding<Bool>) -> some View {
        alert(viewModel.startTripConfirmationTitle, isPresented: isPresented) {
            Button("Cancel", role: .cancel) { }
            Button("Start") {
                Task {
                    do {
                        try await viewModel.StartTrip()
                    } catch {
                        viewModel.ShowError(error)
                    }
                }
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

    func removeMultipleAlert(viewModel: TripRoomViewModel, isPresented: Binding<Bool>) -> some View {
        alert(viewModel.removeConfirmationTitle, isPresented: isPresented) {
            Button("Cancel", role: .cancel) { }
            Button("Remove", role: .destructive) {
                Task {
                    do {
                        try await viewModel.RemoveSelectedParticipants()
                    } catch {
                        viewModel.ShowError(error)
                    }
                }
            }
        }
    }

    func kickAlert(viewModel: TripRoomViewModel, target: Binding<Participant?>) -> some View {
        alert(
            target.wrappedValue.map(viewModel.RemoveParticipantConfirmationTitle) ?? "",
            isPresented: Binding(
                get: { target.wrappedValue != nil },
                set: { if !$0 { target.wrappedValue = nil } }
            )
        ) {
            Button("Cancel", role: .cancel) { target.wrappedValue = nil }
            Button("Remove", role: .destructive) {
                if let participant = target.wrappedValue {
                    Task {
                        do {
                            try await viewModel.RemoveParticipant(id: participant.id)
                        } catch {
                            viewModel.ShowError(error)
                        }
                    }
                }
                target.wrappedValue = nil
            }
        }
    }

    func setLeaderAlert(viewModel: TripRoomViewModel, target: Binding<Participant?>) -> some View {
        alert(
            target.wrappedValue.map(viewModel.SetLeaderConfirmationTitle) ?? "",
            isPresented: Binding(
                get: { target.wrappedValue != nil },
                set: { if !$0 { target.wrappedValue = nil } }
            )
        ) {
            Button("Cancel", role: .cancel) { target.wrappedValue = nil }
            Button("Confirm") {
                if let participant = target.wrappedValue {
                    Task { await viewModel.HandOverLead(to: participant) }
                }
                target.wrappedValue = nil
            }
        }
    }
}

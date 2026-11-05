//
//  EditProfileSheetView.swift
//  Lezgo
//
//  Created by Oky Faishal on 26/10/26.
//

import SwiftUI

/// Edits one participant's avatar, name and car: my own, or anyone's when I lead the trip (US-04, "Edit Profile").
/// When the leader edits a member, "Kick" and "Set Lead" sit between the form and "Save" (US-05).
struct EditProfileSheetView: View {
    let viewModel: TripRoomViewModel
    let participant: Participant
    @Environment(\.dismiss) private var dismiss
    @State private var avatar: Avatar = .yellow
    @State private var name = ""
    @State private var carDetails = ""
    @State private var isConfirmingKick = false
    @State private var isConfirmingSetLead = false
    /// Why Kick or Set Lead failed; the sheet stays open so the leader can try again.
    @State private var groupActionError: String?
    @State private var isRunningGroupAction = false

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedCarDetails: String {
        carDetails.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var displayName: String {
        viewModel.DisplayName(of: participant)
    }

    private var isBusy: Bool {
        viewModel.isSavingProfile || isRunningGroupAction
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    AvatarPicker(selection: $avatar)
                    ProfileField(title: "Name", prompt: "Maximum 30 symbols", text: $name, limit: 30)
                    ProfileField(title: "Car Details", prompt: "Maximum 40 symbols", text: $carDetails, limit: 40)
                    if viewModel.CanKick(participant: participant) {
                        GroupActionButtons(
                            isDisabled: isBusy,
                            onSetLead: { isConfirmingSetLead = true },
                            onKick: { isConfirmingKick = true }
                        )
                    }
                }
                .padding()
            }
            .safeAreaInset(edge: .bottom) {
                SaveButton(isDisabled: trimmedName.isEmpty || isBusy, action: Save)
                    .padding()
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Back", systemImage: "chevron.left") { dismiss() }
                }
            }
            .alert(viewModel.RemoveParticipantConfirmationTitle(for: participant), isPresented: $isConfirmingKick) {
                Button("Cancel", role: .cancel) { }
                Button("Remove", role: .destructive, action: Kick)
            }
            .alert(viewModel.SetLeaderConfirmationTitle(for: participant), isPresented: $isConfirmingSetLead) {
                Button("Cancel", role: .cancel) { }
                Button("Confirm", action: SetLead)
            }
            .alert("Error", isPresented: errorIsShown) {
                Button("OK") { ClearErrors() }
            } message: {
                if let message = viewModel.profileErrorMessage ?? groupActionError {
                    Text(message)
                }
            }
            .onAppear {
                avatar = participant.avatar
                name = participant.displayName
                carDetails = participant.carDescription
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .preferredColorScheme(.dark)
    }

    private var errorIsShown: Binding<Bool> {
        Binding(
            get: { viewModel.profileErrorMessage != nil || groupActionError != nil },
            set: { if !$0 { ClearErrors() } }
        )
    }

    private func ClearErrors() {
        viewModel.profileErrorMessage = nil
        groupActionError = nil
    }

    private func Save() {
        Task {
            let didSave = await viewModel.SaveProfile(
                displayName: trimmedName,
                carDescription: trimmedCarDetails,
                avatar: avatar,
                of: participant.id
            )
            if didSave { dismiss() }
        }
    }

    private func Kick() {
        RunGroupAction { try await viewModel.RemoveParticipant(id: participant.id) }
    }

    private func SetLead() {
        RunGroupAction { try await viewModel.SetLeader(to: participant) }
    }

    /// Closes the sheet once the change is saved; a failure keeps it open with the service's sentence.
    private func RunGroupAction(_ action: @escaping () async throws -> Void) {
        guard !isRunningGroupAction else { return }
        isRunningGroupAction = true
        Task {
            defer { isRunningGroupAction = false }
            do {
                try await action()
                dismiss()
            } catch {
                groupActionError = String(localized: TripServiceError(cloudKitError: error).message)
            }
        }
    }
}

/// "Select Avatar": the five mascots in a row; the chosen one is larger and has the burst.
private struct AvatarPicker: View {
    @Binding var selection: Avatar
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Select Avatar")
                .font(.headline)
            // The chosen avatar is scrolled to the middle, so a member whose avatar is at the end still sees it.
            ScrollViewReader { proxy in
                ScrollView(.horizontal) {
                    HStack(spacing: -50) {
                        ForEach(Avatar.allCases, id: \.self) { avatar in
                            AvatarChoice(avatar: avatar, isChosen: avatar == selection) {
                                withAnimation(reduceMotion ? nil : .snappy) { selection = avatar }
                            }
                            .id(avatar)
                        }
                    }
                    .frame(minHeight: 160)
                }
                .scrollIndicators(.hidden)
                .onChange(of: selection, initial: true) { _, chosen in
                    withAnimation(reduceMotion ? nil : .snappy) { proxy.scrollTo(chosen, anchor: .center) }
                }
            }
        }
    }
}

private struct AvatarChoice: View {
    let avatar: Avatar
    let isChosen: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            AvatarImage(avatar: avatar, isSelected: isChosen)
                .frame(width: isChosen ? 160 : 140, height: isChosen ? 160 : 140)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(avatar.accessibilityName)
        .accessibilityAddTraits(isChosen ? .isSelected : [])
    }
}

private struct ProfileField: View {
    let title: LocalizedStringKey
    let prompt: LocalizedStringKey
    @Binding var text: String
    let limit: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            TextField(title, text: $text, prompt: Text(prompt))
                .padding(.horizontal, 20)
                .frame(minHeight: 52)
                .background(Color(uiColor: .secondarySystemBackground), in: Capsule())
                .onChange(of: text) { _, newValue in
                    if newValue.count > limit {
                        text = String(newValue.prefix(limit))
                    }
                }
        }
    }
}

/// "Set Lead" and "Kick": plain buttons, so they never compete with "Save" (US-05).
private struct GroupActionButtons: View {
    let isDisabled: Bool
    let onSetLead: () -> Void
    let onKick: () -> Void

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) { buttons }
            VStack(spacing: 12) { buttons }
        }
        .disabled(isDisabled)
    }

    @ViewBuilder private var buttons: some View {
        Button(action: onSetLead) {
            Text("Set Lead")
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.bordered)
        .tint(.secondary)
        .foregroundStyle(.primary)
        Button(role: .destructive, action: onKick) {
            Text("Kick")
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.bordered)
        .tint(.secondary)
        .foregroundStyle(.red)
    }
}

private struct SaveButton: View {
    let isDisabled: Bool
    let action: () -> Void

    var body: some View {
        Button("Save", action: action)
            .buttonStyle(.yellowCapsule)
            .disabled(isDisabled)
    }
}

#if DEBUG
private func MakeSheet(me: UUID, editing participantID: UUID) -> some View {
    let state = SampleTrip.State(status: .lobby)
    return Color.black.sheet(isPresented: .constant(true)) {
        if let participant = state.participants.first(where: { $0.id == participantID }) {
            EditProfileSheetView(
                viewModel: TripRoomViewModel(
                    tripService: SampleTrip.Service(status: .lobby, me: me),
                    tripID: SampleTrip.tripID,
                    myParticipantID: me,
                    initialState: state
                ),
                participant: participant
            )
        }
    }
}

#Preview("Leader edits a member") {
    MakeSheet(me: SampleTrip.agusID, editing: SampleTrip.budiID)
}

#Preview("Leader edits themselves") {
    MakeSheet(me: SampleTrip.agusID, editing: SampleTrip.agusID)
}

#Preview("Member, Accessibility XXXL") {
    MakeSheet(me: SampleTrip.budiID, editing: SampleTrip.budiID)
        .dynamicTypeSize(.accessibility5)
}
#endif

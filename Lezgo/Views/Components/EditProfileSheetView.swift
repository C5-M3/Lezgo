//
//  EditProfileSheetView.swift
//  Lezgo
//
//  Created by Oky Faishal on 26/10/26.
//

import SwiftUI

/// Edits one participant's avatar, name and car: my own, or anyone's when I lead the trip (US-04, "Edit Profile").
/// It opens from "Edit Details" in the menu of a held avatar.
struct EditProfileSheetView: View {
    let viewModel: TripRoomViewModel
    let participant: Participant
    @Environment(\.dismiss) private var dismiss
    @State private var avatar: Avatar
    @State private var name: String
    @State private var carDetails: String
    /// The name is already used by another car: set when the field is left, and when a save was refused.
    @State private var isNameTaken = false
    @FocusState private var isNameFocused: Bool

    init(viewModel: TripRoomViewModel, participant: Participant) {
        self.viewModel = viewModel
        self.participant = participant
        _avatar = State(initialValue: participant.avatar)
        _name = State(initialValue: participant.displayName)
        _carDetails = State(initialValue: participant.carDescription)
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedCarDetails: String {
        carDetails.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSave: Bool {
        !trimmedName.isEmpty && !isNameTaken && !viewModel.isSavingProfile
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    AvatarPicker(selection: $avatar)
                    ProfileField(
                        title: "Name",
                        prompt: "Maximum 30 symbols",
                        text: $name,
                        limit: 30,
                        isFocused: $isNameFocused,
                        error: isNameTaken ? .tripServiceErrorNameAlreadyUsed : nil
                    )
                    ProfileField(title: "Car Details", prompt: "Maximum 40 symbols", text: $carDetails, limit: 40)
                }
                .padding()
            }
            .scrollDismissesKeyboard(.interactively)
            .safeAreaInset(edge: .bottom) {
                Button("Save", action: Save)
                    .buttonStyle(.yellowCapsule(disabledBackground: Color(uiColor: .systemGray3)))
                    .disabled(!canSave)
                    .padding()
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Back", systemImage: "chevron.left") { dismiss() }
                }
            }
            .onChange(of: isNameFocused) { _, isFocused in
                // Leaving the field checks the name; tapping it again starts over.
                isNameTaken = !isFocused && viewModel.IsNameTaken(trimmedName, for: participant.id)
            }
            .confirmDialog(
                isPresented: errorIsShown,
                title: Text(verbatim: viewModel.isProfileNameTaken ? (viewModel.profileErrorMessage ?? "") : "Error"),
                message: viewModel.isProfileNameTaken ? nil : viewModel.profileErrorMessage.map { Text(verbatim: $0) },
                cancelTitle: nil,
                confirmTitle: .tripRoomOK,
                onConfirm: { }
            )
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .preferredColorScheme(.dark)
    }

    private var errorIsShown: Binding<Bool> {
        Binding(
            get: { viewModel.profileErrorMessage != nil },
            set: { if !$0 { viewModel.profileErrorMessage = nil } }
        )
    }

    private func Save() {
        Task {
            let didSave = await viewModel.SaveProfile(
                displayName: trimmedName,
                carDescription: trimmedCarDetails,
                avatar: avatar,
                of: participant.id
            )
            if didSave {
                dismiss()
            } else {
                // Checked again on the service: another car may have taken the name since the field was left.
                isNameTaken = viewModel.isProfileNameTaken
            }
        }
    }
}

/// "Select Avatar": the avatars scroll sideways without an end, and the one in the middle is the chosen one. It is the
/// biggest; the others are smaller. There is no select button: scrolling chooses.
private struct AvatarPicker: View {
    @Binding var selection: Avatar
    /// The index of the avatar in the middle, in a list that repeats the five avatars so the end is never reached.
    @State private var position: Int?
    @State private var width: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let copies = 400
    private static let slotWidth: CGFloat = 115
    private let avatars = Avatar.allCases

    init(selection: Binding<Avatar>) {
        _selection = selection
        let middle = Self.copies / 2 * Avatar.allCases.count
        _position = State(initialValue: middle + (Avatar.allCases.firstIndex(of: selection.wrappedValue) ?? 0))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Select Avatar")
                .font(.headline)
            // The list is built only once the width is known: the margins that centre it must exist before the
            // first scroll to the avatar of the participant, or that scroll ends up off to the side.
            Color.clear
                .frame(height: AvatarImage.chosenSize + 20)
                .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
                .overlay { if width > 0 { avatarList } }
        }
        .onChange(of: position) { _, newPosition in
            guard let newPosition else { return }
            selection = avatars[newPosition % avatars.count]
        }
    }

    private var avatarList: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal) {
                LazyHStack(spacing: 0) {
                    ForEach(0..<(Self.copies * avatars.count), id: \.self) { index in
                        AvatarChoice(avatar: avatars[index % avatars.count], isChosen: index == position) {
                            withAnimation(reduceMotion ? nil : .snappy) { position = index }
                        }
                        .frame(width: Self.slotWidth)
                        .id(index)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollPosition(id: $position, anchor: .center)
            .scrollTargetBehavior(.viewAligned)
            .contentMargins(.horizontal, max(0, (width - Self.slotWidth) / 2), for: .scrollContent)
            .scrollIndicators(.hidden)
            .animation(reduceMotion ? nil : .snappy, value: position)
            // Setting the position alone does not centre the first avatar reliably, so scroll to it once shown.
            .task {
                guard let position else { return }
                await Task.yield()
                proxy.scrollTo(position, anchor: .center)
            }
        }
    }
}

private struct AvatarChoice: View {
    let avatar: Avatar
    let isChosen: Bool
    let action: () -> Void

    var body: some View {
        let size = isChosen ? AvatarImage.chosenSize : AvatarImage.pickerSize
        Button(action: action) {
            AvatarImage(avatar: avatar, isSelected: isChosen)
                .frame(width: size, height: size)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(avatar.accessibilityName)
        .accessibilityAddTraits(isChosen ? .isSelected : [])
    }
}

/// A capsule text field with a title. A name that is already used turns the border red and says why underneath.
private struct ProfileField: View {
    let title: LocalizedStringKey
    let prompt: LocalizedStringKey
    @Binding var text: String
    let limit: Int
    var isFocused: FocusState<Bool>.Binding?
    var error: LocalizedStringResource?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            field
                .padding(.horizontal, 20)
                .frame(minHeight: 52)
                .background(Color(uiColor: .secondarySystemBackground), in: Capsule())
                .overlay {
                    if error != nil {
                        Capsule().stroke(.red, lineWidth: 2)
                    }
                }
                .onChange(of: text) { _, newValue in
                    if newValue.count > limit {
                        text = String(newValue.prefix(limit))
                    }
                }
            if let error {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 20)
            }
        }
    }

    @ViewBuilder private var field: some View {
        if let isFocused {
            TextField(title, text: $text, prompt: Text(prompt))
                .focused(isFocused)
                .accessibilityValue(error.map { Text($0) } ?? Text(verbatim: ""))
        } else {
            TextField(title, text: $text, prompt: Text(prompt))
        }
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

#Preview("Member edits themselves") {
    MakeSheet(me: SampleTrip.budiID, editing: SampleTrip.budiID)
}

#Preview("Member, Accessibility XXXL") {
    MakeSheet(me: SampleTrip.budiID, editing: SampleTrip.budiID)
        .dynamicTypeSize(.accessibility5)
}
#endif

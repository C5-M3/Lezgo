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
    /// Asked when the sheet is closed with details that were changed and not saved.
    @State private var isShowingDiscardConfirmation = false
    @FocusState private var focusedField: Field?
    @State private var scrollPosition = ScrollPosition()

    /// The text field that has the keyboard.
    enum Field {
        case name, carDetails
    }

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
        !trimmedName.isEmpty && !isNameTaken
    }

    private var hasChanges: Bool {
        TripRoomViewModel.HasProfileChanges(
            of: participant, displayName: name, carDescription: carDetails, avatar: avatar
        )
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
                        focus: $focusedField,
                        field: .name,
                        error: isNameTaken ? .tripServiceErrorNameAlreadyUsed : nil
                    )
                    ProfileField(
                        title: "Car Details",
                        prompt: "Maximum 40 symbols",
                        text: $carDetails,
                        limit: 40,
                        focus: $focusedField,
                        field: .carDetails
                    )
                }
                .padding()
            }
            // Nothing can be changed while the save is on its way.
            .disabled(viewModel.isSavingProfile)
            .scrollPosition($scrollPosition)
            .scrollDismissesKeyboard(.interactively)
            // Scrolls only when the content is taller than the screen; otherwise the page stays put.
            .scrollBounceBehavior(.basedOnSize)
            .safeAreaInset(edge: .bottom) {
                Button(action: Save) {
                    if viewModel.isSavingProfile {
                        ProgressView()
                            .tint(.black)
                            .accessibilityLabel("Saving")
                    } else {
                        Text("Save")
                    }
                }
                .buttonStyle(.yellowCapsule(disabledBackground: Color(uiColor: .systemGray3)))
                .disabled(!canSave)
                // The spinner keeps the yellow button: a grey one reads as a screen that has stopped answering.
                .allowsHitTesting(!viewModel.isSavingProfile)
                .padding()
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close", systemImage: "xmark", action: Close)
                        .disabled(viewModel.isSavingProfile)
                }
            }
            // Swiping the sheet down would lose the changes without asking; "Close" asks first.
            .interactiveDismissDisabled(hasChanges || viewModel.isSavingProfile)
            .onChange(of: focusedField) { _, field in
                // Leaving the field checks the name; tapping it again starts over.
                isNameTaken = field != .name && viewModel.IsNameTaken(trimmedName, for: participant.id)
                // "Save" rides up with the keyboard; scrolling to the end keeps both fields above it, so the other
                // field can still be tapped. The avatars scroll off the top instead.
                if field != nil {
                    withAnimation { scrollPosition.scrollTo(edge: .bottom) }
                }
            }
            .confirmDialog(
                isPresented: $isShowingDiscardConfirmation,
                title: Text("Discard Changes?"),
                message: Text("Your changes to this profile will not be saved"),
                cancelTitle: "Cancel",
                confirmTitle: "Discard",
                isDestructive: true,
                onConfirm: { dismiss() }
            )
            .confirmDialog(
                isPresented: errorIsShown,
                title: viewModel.isProfileNameTaken
                    ? Text(verbatim: viewModel.profileErrorMessage ?? "")
                    : Text("Error"),
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

    private func Close() {
        if hasChanges {
            focusedField = nil
            isShowingDiscardConfirmation = true
        } else {
            dismiss()
        }
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

/// "Select Avatar": the avatars scroll sideways without an end, and the one in the middle is the chosen one. As in the
/// hi-fi ("HOME - Draft", Edit Profile), the chosen one is the whole mascot and the others are only their heads, with
/// the screen off, getting smaller towards the edges. There is no select button: scrolling chooses.
private struct AvatarPicker: View {
    @Binding var selection: Avatar
    /// The index of the avatar in the middle, in a list that repeats the five avatars so the end is never reached.
    @State private var position: Int?
    @State private var width: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let copies = 400
    private static let slotWidth: CGFloat = 140
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
                // The images have wide transparent margins, so the row is shorter than the chosen image.
                .frame(height: AvatarImage.chosenSize * 0.7)
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
                        AvatarChoice(
                            avatar: avatars[index % avatars.count],
                            distance: abs(index - (position ?? index))
                        ) {
                            withAnimation(reduceMotion ? nil : .snappy) { position = index }
                        }
                        // The chosen mascot is wider than its slot and reaches over its neighbours' empty margins.
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
            // The images' transparent margins reach past the row; clipping them would cut the mascots.
            .scrollClipDisabled()
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
    /// How many places this avatar is from the chosen one in the middle; 0 is the chosen one.
    let distance: Int
    let action: () -> Void

    private var isChosen: Bool { distance == 0 }

    var body: some View {
        Button(action: action) {
            if isChosen {
                AvatarImage(avatar: avatar, isSelected: false)
                    .frame(width: AvatarImage.chosenSize, height: AvatarImage.chosenSize)
            } else {
                Image(headImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: HeadSize(), height: HeadSize())
                    .accessibilityHidden(true)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(avatar.accessibilityName)
        .accessibilityAddTraits(isChosen ? .isSelected : [])
    }

    /// The neighbours are a little bigger than the heads further out, as in the hi-fi. The head fills only about
    /// 40% of its image, so the image is drawn much larger than the head it shows.
    private func HeadSize() -> CGFloat {
        distance == 1 ? 245 : 205
    }

    private var headImage: ImageResource {
        switch avatar {
        case .yellow: .frontballDisactiveYellow
        case .blue: .frontballDisactiveBlue
        case .green: .frontballDisactiveGreen
        case .pink: .frontballDisactivePink
        case .purple: .frontballDisactivePurple
        }
    }
}

/// A capsule text field with a title. A name that is already used turns the border red and says why underneath.
private struct ProfileField: View {
    let title: LocalizedStringKey
    let prompt: LocalizedStringKey
    @Binding var text: String
    let limit: Int
    let focus: FocusState<EditProfileSheetView.Field?>.Binding
    let field: EditProfileSheetView.Field
    var error: LocalizedStringResource?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            textField
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

    private var textField: some View {
        TextField(title, text: $text, prompt: Text(prompt))
            .focused(focus, equals: field)
            .accessibilityValue(error.map { Text($0) } ?? Text(verbatim: ""))
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

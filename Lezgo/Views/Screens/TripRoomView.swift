//
//  TripRoomView.swift
//  Lezgo
//
//  Created by Oky Faishal on 26/10/26.
//

import SwiftUI

@MainActor
struct TripRoomView: View {
    @State private var viewModel: TripRoomViewModel
    @State private var showingInviteSheet = false
    @State private var showingLeaveConfirmation = false
    @State private var showingStartTripConfirmation = false
    @State private var showingRemoveConfirmation = false
    @State private var showingSetLeaderSheet = false
    @State private var participantToKick: Participant?
    @State private var participantToSetLeader: Participant?
    @State private var participantToEdit: Participant?
    @Environment(\.dismiss) private var dismiss

    init(viewModel: TripRoomViewModel) { _viewModel = State(initialValue: viewModel) }
    init() { self.init(viewModel: TripRoomViewModel()) }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(uiColor: .systemGroupedBackground).ignoresSafeArea()
                VStack(spacing: 0) {
                    TopBarView(
                        viewModel: viewModel, onLeave: { showingLeaveConfirmation = true },
                        onSetLeader: { showingSetLeaderSheet = true }
                    ).padding(.bottom, 8)

                    List {
                        RouteSectionView(stops: viewModel.routeStops)
                        ParticipantsSectionView(
                            viewModel: viewModel,
                            onKick: { participantToKick = $0 },
                            onSetLeader: { participantToSetLeader = $0 },
                            onEdit: { participantToEdit = $0 },
                            onInvite: { showingInviteSheet = true }
                        )
                    }
                    .listStyle(.insetGrouped).scrollContentBackground(.hidden)

                    BottomActionView(
                        viewModel: viewModel, onStartTrip: { showingStartTripConfirmation = true },
                        onRemove: { showingRemoveConfirmation = true }
                    ).padding(.horizontal, 16).padding(.vertical, 8)
                }
            }
            .navigationBarBackButtonHidden(true)
            .alert("End Trip?", isPresented: $showingLeaveConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("End Trip", role: .destructive) { viewModel.LeaveRoom(); dismiss() }
            } message: { Text("Leaving without handing over the lead will end the trip for everyone.") }
            .alert("Start trip?", isPresented: $showingStartTripConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Start", action: viewModel.StartTrip)
            }
            .alert(viewModel.removeConfirmationTitle, isPresented: $showingRemoveConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Remove", role: .destructive, action: viewModel.RemoveSelectedParticipants)
            }
            .alert(
                participantToKick.map(viewModel.RemoveParticipantConfirmationTitle) ?? "",
                isPresented: .isPresent($participantToKick)
            ) {
                Button("Cancel", role: .cancel) { participantToKick = nil }
                Button("Remove", role: .destructive) {
                    participantToKick.map { viewModel.RemoveParticipant(id: $0.id) }; participantToKick = nil
                }
            }
            .alert(
                participantToSetLeader.map(viewModel.SetLeaderConfirmationTitle) ?? "",
                isPresented: .isPresent($participantToSetLeader)
            ) {
                Button("Cancel", role: .cancel) { participantToSetLeader = nil }
                Button("Confirm") {
                    participantToSetLeader.map(viewModel.SetLeader(to:)); participantToSetLeader = nil
                }
            }
            .sheet(isPresented: $showingInviteSheet) {
                InviteSheetView(roomCode: viewModel.roomCode, inviteURL: viewModel.inviteURL)
            }
            .sheet(isPresented: $showingSetLeaderSheet) {
                SetLeaderSheetView(participants: viewModel.participants, onSelectLeader: viewModel.SetLeader(to:))
            }
            .sheet(item: $participantToEdit) { participant in
                EditProfileSheetView(participant: participant) { name, desc in
                    viewModel.UpdateParticipant(id: participant.id, name: name, description: desc)
                }
            }
        }
    }
}

// MARK: - Local Subviews

private struct TopBarView: View {
    let viewModel: TripRoomViewModel
    let onLeave: () -> Void
    let onSetLeader: () -> Void

    var body: some View {
        HStack {
            if viewModel.isSelectionMode {
                Button(viewModel.selectAllButtonTitle, action: viewModel.SelectAll)
                    .font(.subheadline.weight(.medium)).foregroundStyle(.primary).padding(.horizontal, 16)
                    .frame(height: 44).background(Color(uiColor: .secondarySystemGroupedBackground), in: Capsule())
                    .buttonStyle(.plain)
            } else {
                Button(action: onLeave) {
                    Image(systemName: "iphone.and.arrow.forward.outward")
                        .rotationEffect(.degrees(180)).circleBarButtonStyle()
                }.buttonStyle(.plain).accessibilityLabel("Leave trip room")
            }
            Spacer()
            if viewModel.isSelectionMode {
                Button(action: viewModel.ToggleSelectionMode) { Image(systemName: "checkmark").circleBarButtonStyle() }
                    .buttonStyle(.plain).accessibilityLabel("Done selecting")
            } else {
                Menu {
                    Button("Select", action: viewModel.ToggleSelectionMode)
                    Button("Set leader", action: onSetLeader)
                } label: { Image(systemName: "ellipsis").circleBarButtonStyle() }
                .buttonStyle(.plain).accessibilityLabel("Room options")
            }
        }.padding(.horizontal, 16)
    }
}

private extension View {
    func circleBarButtonStyle() -> some View {
        font(.system(size: 18, weight: .semibold)).foregroundStyle(.primary)
            .frame(width: 44, height: 44).background(Color(uiColor: .secondarySystemGroupedBackground), in: Circle())
            .accessibilityHidden(true)
    }
}

private extension Binding {
    static func isPresent<Wrapped>(_ value: Binding<Wrapped?>) -> Binding<Bool> {
        Binding<Bool>(get: { value.wrappedValue != nil }, set: { if !$0 { value.wrappedValue = nil } })
    }
}

private struct RouteSectionView: View {
    let stops: [TripRoomViewModel.RouteStop]

    var body: some View {
        Section("Route Trip") {
            ForEach(stops) { stop in
                HStack(spacing: 12) {
                    Image(systemName: stop.kind.iconName)
                        .font(stop.kind == .checkpoint ? .system(size: 8) : .system(size: 16, weight: .semibold))
                        .foregroundStyle(stop.kind == .checkpoint ? .secondary : .primary)
                        .frame(width: 20, height: 20).accessibilityHidden(true)
                    Text(stop.name).font(.body).lineLimit(2)
                    Spacer()
                }
                .padding(.vertical, 4).accessibilityElement(children: .combine)
                .accessibilityLabel("\(stop.kind.accessibilityPrefix): \(stop.name)")
            }
        }
    }
}

private struct ParticipantsSectionView: View {
    let viewModel: TripRoomViewModel
    let onKick: (Participant) -> Void
    let onSetLeader: (Participant) -> Void
    let onEdit: (Participant) -> Void
    let onInvite: () -> Void

    var body: some View {
        Section {
            if viewModel.participants.isEmpty {
                Text("No participants yet").font(.subheadline).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity).padding(.vertical, 12)
            } else {
                ForEach(viewModel.participants) { participant in
                    ParticipantRowView(participant: participant, viewModel: viewModel, onEdit: { onEdit(participant) })
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            if viewModel.CanKick(participant: participant) {
                                Button { onKick(participant) } label: { Image(systemName: "trash") }
                                    .tint(.red).accessibilityLabel("Kick")
                            }
                        }
                        .swipeActions(edge: .leading, allowsFullSwipe: false) {
                            if viewModel.CanSetLeader(participant: participant) {
                                Button { onSetLeader(participant) } label: { Image(systemName: "crown.fill") }
                                    .tint(Color(uiColor: .systemGray)).accessibilityLabel("Set leader")
                            }
                        }
                }
            }
        } header: {
            HStack {
                Text("Participants").font(.headline).foregroundStyle(.primary).textCase(nil)
                Spacer()
                Button(action: onInvite) {
                    Image(systemName: "plus").font(.system(size: 14, weight: .bold)).accessibilityHidden(true)
                        .frame(width: 32, height: 32)
                        .background(Color(uiColor: .secondarySystemGroupedBackground), in: .rect(cornerRadius: 8))
                }.buttonStyle(.plain).frame(minWidth: 44, minHeight: 44).accessibilityLabel("Invite participant")
            }
        }
    }
}

private struct ParticipantRowContent: View {
    let participant: Participant

    var body: some View {
        HStack(spacing: 12) {
            Circle().fill(Color.secondary.opacity(participant.isLeader ? 0.15 : 0.3)).frame(width: 36, height: 36)
                .overlay { Text(String(participant.name.prefix(1))).font(.subheadline.bold()) }
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(participant.name).font(.body.weight(.medium))
                Text(participant.description).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if participant.isLeader {
                Image(systemName: "crown.fill").font(.system(size: 16))
                    .foregroundStyle(.secondary).accessibilityLabel("Leader")
            }
        }
    }
}

private struct ParticipantRowView: View {
    let participant: Participant
    let viewModel: TripRoomViewModel
    let onEdit: () -> Void

    private var isSelected: Bool { viewModel.selectedParticipantIds.contains(participant.id) }

    var body: some View {
        Button {
            if viewModel.isSelectionMode {
                viewModel.ToggleParticipantSelection(id: participant.id)
            } else if viewModel.CanEdit(participant: participant) {
                onEdit()
            }
        } label: {
            HStack(spacing: 12) {
                if viewModel.isSelectionMode && !participant.isLeader {
                    ZStack {
                        Circle().fill(Color(uiColor: .systemGray4))
                        if isSelected { Image(systemName: "checkmark").font(.system(size: 12, weight: .bold)) }
                    }.frame(width: 24, height: 24).accessibilityHidden(true)
                }
                ParticipantRowContent(participant: participant)
            }
            .padding(.vertical, 4).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(
            (viewModel.isSelectionMode && !participant.isLeader) || viewModel.CanEdit(participant: participant)
                ? .isButton : []
        )
    }

    private var accessibilityLabel: String {
        let role = participant.isLeader ? ", Leader" : ""
        let selection = viewModel.isSelectionMode ? (isSelected ? ", Selected" : ", Not selected") : ""
        return "\(participant.name), \(participant.description)\(role)\(selection)"
    }
}

private struct BottomActionView: View {
    let viewModel: TripRoomViewModel
    let onStartTrip: () -> Void
    let onRemove: () -> Void

    var body: some View {
        if viewModel.isSelectionMode {
            HStack {
                Spacer()
                Button("Remove", action: onRemove)
                    .font(.headline).foregroundStyle(viewModel.canRemove ? .primary : .secondary)
                    .padding(.horizontal, 24).frame(height: 44).buttonStyle(.plain).disabled(!viewModel.canRemove)
                    .background(
                        Color(uiColor: .secondarySystemGroupedBackground).opacity(viewModel.canRemove ? 1 : 0.6),
                        in: Capsule()
                    )
                    .accessibilityLabel("Remove selected participants")
            }
        } else {
            Group {
                if viewModel.isCurrentUserLeader {
                    Button("Start Trip", action: onStartTrip).buttonStyle(.plain).accessibilityLabel("Start Trip")
                } else {
                    Text("Waiting for leader to start...").font(.subheadline)
                }
            }
            .font(.headline).foregroundStyle(.primary).frame(maxWidth: .infinity, minHeight: 52)
            .background(Color.white, in: .rect(cornerRadius: 14))
        }
    }
}

private struct InviteSheetView: View {
    let roomCode: String
    let inviteURL: URL

    var body: some View {
        VStack(spacing: 20) {
            Text(roomCode).font(.system(size: 38, weight: .heavy, design: .rounded)).tracking(2)
                .foregroundStyle(.white).frame(maxWidth: .infinity, minHeight: 110)
                .background(Color(uiColor: .systemGray), in: .rect(cornerRadius: 16))
                .accessibilityLabel("Room code: \(roomCode.map(String.init).joined(separator: ", "))")
            HStack(spacing: 12) {
                Rectangle().fill(Color(uiColor: .separator)).frame(height: 1)
                Text("or").font(.subheadline).foregroundStyle(.secondary)
                Rectangle().fill(Color(uiColor: .separator)).frame(height: 1)
            }
            ShareLink(item: inviteURL) {
                Label("Share Link", systemImage: "link").font(.headline).foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(Color(uiColor: .systemGray), in: .rect(cornerRadius: 14))
            }.accessibilityLabel("Share Link")
        }
        .padding(.horizontal, 20).padding(.vertical, 24)
        .presentationDetents([.height(270)]).presentationDragIndicator(.visible)
    }
}

private struct SetLeaderSheetView: View {
    let participants: [Participant]
    let onSelectLeader: (Participant) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var candidate: Participant?

    var body: some View {
        NavigationStack {
            List(participants) { participant in
                Button { candidate = participant } label: { ParticipantRowContent(participant: participant) }
                    .buttonStyle(.plain).disabled(participant.isLeader).opacity(participant.isLeader ? 0.5 : 1.0)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(
                        "\(participant.name), \(participant.description), \(participant.isLeader ? "Leader" : "Select")"
                    )
                    .accessibilityAddTraits(participant.isLeader ? [] : .isButton)
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Pick Your New Leader").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
            .alert("Set \(candidate?.name ?? "") as Trip Leader?", isPresented: .isPresent($candidate)) {
                Button("Cancel", role: .cancel) { candidate = nil }
                Button("Confirm") { candidate.map(onSelectLeader); dismiss() }
            }
        }
    }
}

private struct EditProfileSheetView: View {
    let participant: Participant
    let onUpdate: (String, String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var description = ""
    @FocusState private var isNameFocused: Bool

    private var trimmedName: String { name.trimmingCharacters(in: .whitespaces) }

    var body: some View {
        NavigationStack {
            Form {
                Section("Profile Details") {
                    TextField("Name", text: $name).focused($isNameFocused)
                    TextField("Description", text: $description)
                }
            }
            .navigationTitle("Edit Profile").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Update") { onUpdate(trimmedName, description); dismiss() }.disabled(trimmedName.isEmpty)
                }
            }
            .onAppear { name = participant.name; description = participant.description; isNameFocused = true }
        }
        .presentationDetents([.medium, .large])
    }
}

#Preview {
    TripRoomView()
}

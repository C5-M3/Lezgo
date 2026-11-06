//
//  HeldAvatarOverlay.swift
//  Lezgo
//
//  Created by Oky Faishal on 06/11/26.
//

import SwiftUI

/// What opens when an avatar is held in the Trip Room (US-04, "Manage participants"): the screen goes dark, the avatar
/// sits in the middle of the screen with its name and car, and a black menu of actions sits below it.
///
/// Built here and not with `contextMenu`, because the system draws its own card behind the preview and a glass menu,
/// and neither can be restyled. Tapping outside closes it.
struct HeldAvatarOverlay: View {
    let participant: Participant
    let displayName: String
    let actions: [TripRoomViewModel.ParticipantAction]
    let onSelect: (TripRoomViewModel.ParticipantAction) -> Void
    let onDismiss: () -> Void

    private let avatarSize: CGFloat = 200
    private let menuWidth: CGFloat = 280

    var body: some View {
        ZStack {
            Color.black.opacity(0.7)
                .background(.ultraThinMaterial.opacity(0.35))
                .ignoresSafeArea()
                .onTapGesture(perform: onDismiss)
                .accessibilityHidden(true)
            // The avatar alone is centered; the text and the menu hang below it, so they do not push it up.
            AvatarImage(avatar: participant.avatar, isSelected: true)
                .frame(width: avatarSize, height: avatarSize)
                .overlay(alignment: .top) {
                    VStack(spacing: 16) {
                        details
                        menu
                    }
                    .frame(width: menuWidth)
                    .padding(.top, avatarSize)
                }
        }
        .ignoresSafeArea()
        .environment(\.colorScheme, .dark) // The Trip Room has no light mode.
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
        .accessibilityAction(.escape, onDismiss)
    }

    private var details: some View {
        VStack(spacing: 2) {
            Text(displayName)
                .font(.title3.bold())
                .foregroundStyle(.white)
            if !participant.carDescription.isEmpty {
                Text(participant.carDescription)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .multilineTextAlignment(.center)
        .accessibilityElement(children: .combine)
    }

    private var menu: some View {
        VStack(spacing: 0) {
            ForEach(Array(actions.enumerated()), id: \.element) { index, action in
                if index > 0 { Divider().overlay(Color.white.opacity(0.15)) }
                Button { onSelect(action) } label: {
                    action.label
                        .font(.body)
                        .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
                        .padding(.horizontal)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .foregroundStyle(action.isDestructive ? Color.red : Color.white)
            }
        }
        .background(Color(white: 0.1), in: .rect(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.12)))
    }
}

extension TripRoomViewModel.ParticipantAction {
    /// The title and icon of this action, in the menu and in VoiceOver's action list.
    @ViewBuilder var label: some View {
        switch self {
        case .setLeader: Label("Set as Trip Leader", systemImage: "crown")
        case .editDetails: Label("Edit Details", systemImage: "pencil")
        case .remove: Label("Remove from Trip", systemImage: "person.badge.minus")
        }
    }

    var isDestructive: Bool { self == .remove }
}

#if DEBUG
#Preview("Leader holds Budi") {
    HeldAvatarOverlay(
        participant: SampleTrip.State(status: .lobby).participants[1],
        displayName: "Budi",
        actions: [.setLeader, .editDetails, .remove],
        onSelect: { _ in },
        onDismiss: {}
    )
    .background(.gray)
    .preferredColorScheme(.dark)
}
#endif

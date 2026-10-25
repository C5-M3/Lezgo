import SwiftUI

/// Modal sheet allowing the current trip leader to transfer leadership to another participant.
public struct SetLeaderSheetView: View {
    public let participants: [Participant]
    public let onSelectLeader: (Participant) -> Void

    @State private var participantToConfirm: Participant?
    @Environment(\.dismiss) private var dismiss

    public init(
        participants: [Participant],
        onSelectLeader: @escaping (Participant) -> Void
    ) {
        self.participants = participants
        self.onSelectLeader = onSelectLeader
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                Color(uiColor: .systemGroupedBackground)
                    .ignoresSafeArea()

                VStack(spacing: 24) {
                    // Top Bar with Cancel button
                    HStack {
                        Button("Cancel") {
                            dismiss()
                        }
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 16)
                        .frame(height: 44)
                        .background(Color(uiColor: .secondarySystemGroupedBackground))
                        .clipShape(Capsule())
                        .buttonStyle(.plain)
                        .accessibilityLabel("Cancel")

                        Spacer()
                    }

                    // Centered Headline
                    Text("Pick Your New Leader")
                        .font(.title2.bold())
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 8)

                    // Participants Selection Card
                    VStack(spacing: 0) {
                        ForEach(Array(participants.enumerated()), id: \.element.id) { index, participant in
                            LeaderCandidateRow(
                                participant: participant,
                                onSelect: {
                                    participantToConfirm = participant
                                }
                            )

                            if index < participants.count - 1 {
                                Divider()
                                    .padding(.leading, 56)
                            }
                        }
                    }
                    .background(Color(uiColor: .secondarySystemGroupedBackground))
                    .clipShape(.rect(cornerRadius: 16))

                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
            }
            .navigationBarBackButtonHidden(true)
            .alert(
                confirmationTitle,
                isPresented: Binding(
                    get: { participantToConfirm != nil },
                    set: { if !$0 { participantToConfirm = nil } }
                )
            ) {
                Button("Cancel", role: .cancel) {
                    participantToConfirm = nil
                }
                Button("Confirm") {
                    if let chosen = participantToConfirm {
                        onSelectLeader(chosen)
                        dismiss()
                    }
                }
            }
        }
    }

    private var confirmationTitle: String {
        guard let participant = participantToConfirm else { return "" }
        return "Set \(participant.name) as Trip Leader?"
    }
}

private struct LeaderCandidateRow: View {
    let participant: Participant
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                Circle()
                    .fill(Color.secondary.opacity(participant.isLeader ? 0.15 : 0.3))
                    .frame(width: 36, height: 36)
                    .overlay {
                        Text(String(participant.name.prefix(1)))
                            .font(.subheadline.bold())
                            .foregroundStyle(participant.isLeader ? .secondary : .primary)
                    }
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(participant.name)
                        .font(.body.weight(.medium))
                        .foregroundStyle(participant.isLeader ? .secondary : .primary)

                    Text(participant.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if participant.isLeader {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.secondary)
                        .accessibilityLabel("Current Leader")
                }
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(participant.isLeader)
        .opacity(participant.isLeader ? 0.5 : 1.0)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(AccessibilityRowLabel())
        .accessibilityAddTraits(participant.isLeader ? [] : .isButton)
    }

    private func AccessibilityRowLabel() -> String {
        if participant.isLeader {
            return "\(participant.name), \(participant.description), Current Leader, Cannot be selected"
        } else {
            return "\(participant.name), \(participant.description), Select as new leader"
        }
    }
}

// MARK: - Previews

#Preview {
    SetLeaderSheetView(
        participants: [
            Participant(name: "Faishal (You)", description: "Innova Hitam - B 1234 CD", isLeader: true),
            Participant(name: "Matthew", description: "Civic Putih - B 8888 XY", isLeader: false),
            Participant(name: "Farr", description: "HR-V Abu-abu - B 4321 EF", isLeader: false)
        ],
        onSelectLeader: { _ in }
    )
}

#if DEBUG
import SwiftUI

/// The content of `SyncCheckView`: the trip, its members, the leader's actions and the log of changes.
struct SyncCheckForm: View {
    @Bindable var viewModel: SyncCheckViewModel

    var body: some View {
        Form {
            if let state = viewModel.state {
                TripSection(state: state)
                ParticipantsSection(state: state)
                if viewModel.isLeader {
                    LeaderSection(status: state.trip.status)
                }
            } else {
                StartSection()
            }
            if let errorMessage = viewModel.errorMessage {
                Section {
                    Label { Text(verbatim: errorMessage) } icon: { Image(systemName: "exclamationmark.triangle") }
                }
            }
            LogSection()
        }
        .disabled(viewModel.isBusy)
        .task(id: viewModel.session?.state.trip.id) {
            await viewModel.Listen()
        }
    }

    private func StartSection() -> some View {
        Section {
            Button { Task { await viewModel.CreateTrip() } } label: { Text(verbatim: "Create trip") }
            TextField(text: $viewModel.roomCodeInput) { Text(verbatim: "Room code") }
                .keyboardType(.numberPad)
            Button { Task { await viewModel.JoinTrip() } } label: { Text(verbatim: "Join trip") }
                .disabled(viewModel.canJoin == false)
        } header: {
            Text(verbatim: "Start")
        }
    }

    private func TripSection(state: TripState) -> some View {
        Section {
            LabeledContent { Text(verbatim: state.trip.roomCode).font(.title.monospacedDigit()) } label: {
                Text(verbatim: "Room code")
            }
            LabeledContent { Text(verbatim: state.trip.status.rawValue) } label: { Text(verbatim: "Status") }
            LabeledContent { Text(verbatim: viewModel.isLeader ? "Leader" : "Member") } label: {
                Text(verbatim: "I am")
            }
            LabeledContent { Text(verbatim: "\(state.trip.routeVersion)") } label: { Text(verbatim: "Route version") }
        } header: {
            Text(verbatim: "Trip")
        }
    }

    private func ParticipantsSection(state: TripState) -> some View {
        Section {
            ForEach(state.participants) { participant in
                let isLeader = participant.IsLeader(in: state.trip)
                let isMe = participant.id == viewModel.myParticipantID
                HStack {
                    VStack(alignment: .leading) {
                        Text(verbatim: participant.displayName + (isMe ? " (this phone)" : ""))
                        Text(verbatim: participant.userRecordID)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if isLeader {
                        Image(systemName: "crown.fill")
                            .accessibilityLabel(Text(verbatim: "Leader"))
                    } else if viewModel.isLeader {
                        Button { Task { await viewModel.HandOverLead(to: participant.id) } } label: {
                            Text(verbatim: "Make leader")
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
        } header: {
            Text(verbatim: "Participants (\(state.participants.count))")
        }
    }

    private func LeaderSection(status: TripStatus) -> some View {
        Section {
            if status == .lobby {
                Button { Task { await viewModel.StartTrip() } } label: { Text(verbatim: "Start trip") }
            }
            if status.isOpen {
                Button(role: .destructive) { Task { await viewModel.EndTrip() } } label: { Text(verbatim: "End trip") }
            }
        } header: {
            Text(verbatim: "Leader")
        }
    }

    private func LogSection() -> some View {
        Section {
            ForEach(viewModel.log) { entry in
                HStack(alignment: .firstTextBaseline) {
                    Text(entry.seenAt.formatted(.dateTime.hour().minute().second()))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                    Text(verbatim: entry.message)
                }
            }
        } header: {
            Text(verbatim: "Log (newest first)")
        }
    }
}
#endif

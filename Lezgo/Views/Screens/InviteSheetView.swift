//
//  InviteSheetView.swift
//  Lezgo
//
//  Created by Oky Faishal on 26/10/26.
//

import SwiftUI

struct InviteSheetView: View {
    let viewModel: TripRoomViewModel
    @State private var didCopy = false
    /// Goes up with every copy, so a new tap restarts the 2 seconds that "Copied" stays on screen.
    @State private var copyCount = 0

    var body: some View {
        ScrollView {
            VStack {
                RoomCodeView(roomCode: viewModel.roomCode, isLoaded: viewModel.canShareInvite)
                Button(action: CopyCode) {
                    Label {
                        Text(didCopy ? LocalizedStringResource.tripRoomCopied : .tripRoomCopyCode)
                    } icon: {
                        Image(systemName: didCopy ? "checkmark" : "doc.on.doc")
                            .contentTransition(.symbolEffect(.replace))
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                HStack {
                    VStack { Divider() }
                    Text("or").font(.subheadline).foregroundStyle(.secondary)
                    VStack { Divider() }
                }
                ShareLink(item: viewModel.inviteURL, message: Text(viewModel.shareMessage)) {
                    Label("Share Link", systemImage: "link")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
            .font(.headline)
            .controlSize(.large)
            .disabled(!viewModel.canShareInvite)
            .padding()
        }
        .scrollBounceBehavior(.basedOnSize)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .sensoryFeedback(.success, trigger: copyCount)
        .task(id: copyCount) {
            guard copyCount > 0, (try? await Task.sleep(for: .seconds(2))) != nil else { return }
            didCopy = false
        }
    }

    private func CopyCode() {
        UIPasteboard.general.string = viewModel.roomCode
        didCopy = true
        copyCount += 1
        AccessibilityNotification.Announcement(String(localized: .tripRoomCopied)).post()
    }
}

private struct RoomCodeView: View {
    let roomCode: String
    let isLoaded: Bool

    var body: some View {
        Group {
            if isLoaded {
                Text(roomCode)
                    .font(.system(.largeTitle, design: .rounded, weight: .heavy).monospacedDigit())
                    .tracking(2)
                    .accessibilityLabel("Room code: \(roomCode.map(String.init).joined(separator: ", "))")
            } else {
                ProgressView()
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .background(.fill.tertiary, in: .rect(cornerRadius: 16))
    }
}

#if DEBUG
#Preview("Room code loaded") {
    Color.clear.sheet(isPresented: .constant(true)) {
        InviteSheetView(viewModel: TripRoomViewModel(
            tripService: SampleTrip.Service(status: .lobby, me: SampleTrip.budiID),
            tripID: SampleTrip.tripID,
            myParticipantID: SampleTrip.budiID,
            initialState: SampleTrip.State(status: .lobby)
        ))
    }
}

#Preview("Room code loading") {
    Color.clear.sheet(isPresented: .constant(true)) {
        InviteSheetView(viewModel: TripRoomViewModel(
            tripService: SampleTrip.Service(status: .lobby, me: SampleTrip.budiID),
            tripID: SampleTrip.tripID,
            myParticipantID: SampleTrip.budiID
        ))
    }
}

#Preview("Dark mode") {
    Color.clear.sheet(isPresented: .constant(true)) {
        InviteSheetView(viewModel: TripRoomViewModel(
            tripService: SampleTrip.Service(status: .lobby, me: SampleTrip.budiID),
            tripID: SampleTrip.tripID,
            myParticipantID: SampleTrip.budiID,
            initialState: SampleTrip.State(status: .lobby)
        ))
    }
    .preferredColorScheme(.dark)
}

#Preview("Accessibility XXXL") {
    Color.clear.sheet(isPresented: .constant(true)) {
        InviteSheetView(viewModel: TripRoomViewModel(
            tripService: SampleTrip.Service(status: .lobby, me: SampleTrip.budiID),
            tripID: SampleTrip.tripID,
            myParticipantID: SampleTrip.budiID,
            initialState: SampleTrip.State(status: .lobby)
        ))
        .dynamicTypeSize(.accessibility5)
    }
}
#endif

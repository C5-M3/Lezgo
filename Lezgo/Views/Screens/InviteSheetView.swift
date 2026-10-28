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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                RoomCodeView(roomCode: viewModel.roomCode, isLoaded: viewModel.canShareInvite)
                Button(action: CopyCode) {
                    Label {
                        Text(didCopy ? LocalizedStringResource.tripRoomCopied : .tripRoomCopyCode)
                    } icon: {
                        Image(systemName: didCopy ? "checkmark" : "doc.on.doc")
                    }
                    .inviteButtonStyle()
                }
                .buttonStyle(.plain)
                .disabled(!viewModel.canShareInvite)
                HStack(spacing: 12) {
                    Rectangle().fill(Color(uiColor: .separator)).frame(height: 1)
                    Text("or").font(.subheadline).foregroundStyle(.secondary)
                    Rectangle().fill(Color(uiColor: .separator)).frame(height: 1)
                }
                ShareLink(item: viewModel.inviteURL, message: Text(viewModel.shareMessage)) {
                    Label("Share Link", systemImage: "link")
                        .inviteButtonStyle()
                }
                .disabled(!viewModel.canShareInvite)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
        }
        .scrollBounceBehavior(.basedOnSize)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .task(id: copyCount) {
            guard copyCount > 0, (try? await Task.sleep(for: .seconds(2))) != nil else { return }
            withAnimation(reduceMotion ? nil : .default) { didCopy = false }
        }
    }

    private func CopyCode() {
        UIPasteboard.general.string = viewModel.roomCode
        withAnimation(reduceMotion ? nil : .default) { didCopy = true }
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
                    .font(.system(size: 38, weight: .heavy, design: .rounded))
                    .tracking(2)
                    .accessibilityLabel("Room code: \(roomCode.map(String.init).joined(separator: ", "))")
            } else {
                ProgressView()
                    .tint(.white)
            }
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, minHeight: 110)
        .background(Color(uiColor: .systemGray), in: .rect(cornerRadius: 16))
    }
}

private extension View {
    func inviteButtonStyle() -> some View {
        font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(Color(uiColor: .systemGray), in: .rect(cornerRadius: 14))
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

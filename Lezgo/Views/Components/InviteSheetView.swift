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
    /// The sheet is as tall as its content, like the lo-fi, and grows with Dynamic Type.
    @State private var contentHeight: CGFloat = 270
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Button(action: CopyCode) {
                    RoomCodeView(roomCode: viewModel.roomCode, isLoaded: viewModel.canShareInvite, didCopy: didCopy)
                }
                .buttonStyle(.plain)
                .accessibilityHint(Text(.tripRoomCopyCode))
                .contextMenu {
                    Button(.tripRoomCopyCode, systemImage: "doc.on.doc", action: CopyCode)
                }
                HStack {
                    VStack { Divider() }
                    Text("or").font(.subheadline)
                    VStack { Divider() }
                }
                ShareLink(item: viewModel.inviteURL, message: Text(viewModel.shareMessage)) {
                    Label("Share Link", systemImage: "link")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .foregroundStyle(.primary)
                .buttonStyle(.borderedProminent)
                // Opaque, like the code box, so nothing behind the sheet shows through and lowers the contrast.
                .tint(Color(uiColor: .systemGray4))
                .controlSize(.large)
            }
            .disabled(!viewModel.canShareInvite)
            .padding(.horizontal)
            .padding(.vertical, 24)
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { contentHeight = $0 }
        }
        .scrollBounceBehavior(.basedOnSize)
        .presentationDetents([.height(contentHeight)])
        .presentationDragIndicator(.visible)
        .sensoryFeedback(.success, trigger: copyCount)
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
    let didCopy: Bool

    var body: some View {
        // "Copied" and the loading spinner always take the same space, so the box (and the sheet) never changes
        // height. The hidden label on top balances the one below, which keeps the code in the middle of the box.
        VStack(spacing: 4) {
            CopiedLabel().hidden()
            if isLoaded {
                RoomCodeText(roomCode: roomCode)
                    .accessibilityLabel("Room code: \(roomCode.map(String.init).joined(separator: ", "))")
            } else {
                RoomCodeText(roomCode: "000000")
                    .hidden()
                    .overlay { ProgressView() }
            }
            if didCopy {
                CopiedLabel()
                    .transition(.opacity)
            } else {
                CopiedLabel().hidden()
            }
        }
        .foregroundStyle(.primary)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color(uiColor: .systemGray4), in: .rect(cornerRadius: 16))
        .contentShape(.rect(cornerRadius: 16))
    }
}

private struct RoomCodeText: View {
    let roomCode: String

    var body: some View {
        Text(verbatim: roomCode)
            .font(.system(.largeTitle, design: .rounded, weight: .heavy).monospacedDigit())
            .tracking(2)
    }
}

private struct CopiedLabel: View {
    var body: some View {
        Label {
            Text(.tripRoomCopied)
        } icon: {
            Image(systemName: "checkmark")
        }
        .font(.subheadline.weight(.semibold))
        .accessibilityHidden(true)
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

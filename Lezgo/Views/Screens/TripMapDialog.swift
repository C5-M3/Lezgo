//
//  TripMapDialog.swift
//  Lezgo
//
//  Created by Nathan Sudiara on 05/11/26.
//

import SwiftUI

/// The dark question or message over the trip map, instead of a system alert: "Exit trip?", "End trip?" and the
/// messages about leaving. `specs/UserStories.md` → US-07, "Leave and end".
struct TripMapDialog: View {
    let title: Text
    var message: Text?
    /// "Cancel"; `nil` for a message with a single button.
    var cancel: (() -> Void)?
    let confirmTitle: Text
    /// Red for what ends the trip for everyone, yellow for the rest.
    var isDestructive = false
    var isConfirmDisabled = false
    let confirm: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// `false` for the moment the dialog arrives, so its card grows into place while the dark backdrop fades in.
    @State private var hasArrived = false

    var body: some View {
        ZStack {
            // Taps outside the dialog do nothing: the answer must be a choice, not an accident.
            Color.black.opacity(0.7)
                .ignoresSafeArea()
                .accessibilityHidden(true)

            ViewThatFits(in: .vertical) {
                Card()
                ScrollView { Card() }
            }
            .frame(maxWidth: 330)
            .padding(.horizontal, 24)
            .padding(.vertical)
            .scaleEffect(hasArrived || reduceMotion ? 1 : 0.9)
        }
        .onAppear {
            withAnimation(Animation.lezgoDialog.Respecting(reduceMotion: reduceMotion)) { hasArrived = true }
        }
        .contentShape(.rect)
        .accessibilityAddTraits(.isModal)
    }

    private func Card() -> some View {
        VStack(spacing: 10) {
            title
                .font(.title3.bold())
                .foregroundStyle(.white)
            if let message {
                message
                    .font(.subheadline)
                    .foregroundStyle(Color(.tripCardSubtext))
            }
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) { Buttons() }
                VStack(spacing: 12) { Buttons() }
            }
            .padding(.top, 18)
        }
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(Color(.tripCardButton), in: .rect(cornerRadius: 30))
    }

    @ViewBuilder
    private func Buttons() -> some View {
        if let cancel {
            Button(action: cancel) {
                Text(.tripMapCancel)
                    .modifier(ButtonLabel(foreground: .white, background: Color(.tripCardSubtext).opacity(0.25)))
            }
            .buttonStyle(.pressable)
        }
        Button(action: confirm) {
            confirmTitle
                .modifier(ButtonLabel(
                    foreground: Color(.tripCard),
                    background: isDestructive ? Color(.tripAlertRed) : Color(.brandYellow)
                ))
        }
        .buttonStyle(.pressable)
        .disabled(isConfirmDisabled)
        .opacity(isConfirmDisabled ? 0.5 : 1)
        .animation(.lezgoFade, value: isConfirmDisabled)
    }
}

extension TripMapDialog {
    /// The text of a dialog button, in its colored capsule.
    struct ButtonLabel: ViewModifier {
        let foreground: Color
        let background: Color

        func body(content: Content) -> some View {
            content
                .font(.body.bold())
                .foregroundStyle(foreground)
                .padding(.horizontal, 12)
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(background, in: .capsule)
                .contentShape(.capsule)
        }
    }
}

#Preview("Exit trip") {
    TripMapDialog(
        title: Text(.tripMapExitTripQuestion),
        message: Text(.tripMapExitTripMessage),
        cancel: {},
        confirmTitle: Text(.tripMapConfirm),
        confirm: {}
    )
}

#Preview("End trip, not everyone arrived") {
    TripMapDialog(
        title: Text(.tripMapEndTripQuestion),
        message: Text(.tripMapEndTripNotEveryoneMessage),
        cancel: {},
        confirmTitle: Text(.tripMapConfirm),
        isDestructive: true,
        confirm: {}
    )
}

#Preview("I've Arrived") {
    TripMapDialog(
        title: Text(.tripMapArrivedQuestion("Tunjungan Plaza")),
        message: Text(.tripMapArrivedMessage("200 m")),
        cancel: {},
        confirmTitle: Text(.tripMapIveArrived),
        confirm: {}
    )
}

#Preview("A message, largest text") {
    TripMapDialog(title: Text(.tripMapLeaderEndedTrip), confirmTitle: Text(.tripMapOK), confirm: {})
        .dynamicTypeSize(.accessibility5)
}

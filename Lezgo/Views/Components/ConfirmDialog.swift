//
//  ConfirmDialog.swift
//  Lezgo
//
//  Created by Oky Faishal on 06/11/26.
//

import SwiftUI

/// The one alert of the app, drawn as in the hi-fi ("H2 Has Arrived · Confirm"): a dark card over a dimmed screen
/// with a centred title, an optional message, a grey "Cancel" and the main button in a yellow capsule, or a red one
/// for what cannot be undone. A system alert cannot take these colours or show the LEZGO logo on its button, so every
/// question and message in the app uses this one. Tapping outside does nothing: the person picks a button.
///
/// The main button's content is a view, so it can be text or an image. Without `cancelTitle` there is only the main
/// button, for messages that just say "OK".
struct ConfirmDialog<Confirm: View>: View {
    let title: Text
    var message: Text?
    var cancelTitle: LocalizedStringResource? = .tripRoomCancel
    /// Red for what ends or throws away something, yellow for the rest.
    var isDestructive = false
    /// While the answer is being saved, so a second tap cannot send it twice.
    var isConfirmDisabled = false
    var onCancel: () -> Void = {}
    let onConfirm: () -> Void
    @ViewBuilder let confirm: Confirm

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// `false` for the moment the dialog arrives, so its card grows into place while the dark backdrop fades in.
    @State private var hasArrived = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.7)
                .ignoresSafeArea()
                .accessibilityHidden(true)

            // At the largest text sizes the card scrolls instead of being cut off.
            ViewThatFits(in: .vertical) {
                Card()
                ScrollView { Card() }
            }
            .frame(maxWidth: 330)
            .padding(.horizontal, 24)
            .padding(.vertical)
            .scaleEffect(hasArrived || reduceMotion ? 1 : 0.9)
        }
        .contentShape(.rect)
        .onAppear {
            withAnimation(Animation.lezgoDialog.Respecting(reduceMotion: reduceMotion)) { hasArrived = true }
        }
        .accessibilityAddTraits(.isModal)
        .accessibilityAction(.escape) { cancelTitle == nil ? onConfirm() : onCancel() }
    }

    private func Card() -> some View {
        VStack(spacing: 10) {
            title
                .font(.title3.bold())
                .foregroundStyle(.white)
                .accessibilityAddTraits(.isHeader)
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
        // Named after its title, so VoiceOver and the UI tests find the dialog by what it asks.
        .accessibilityElement(children: .contain)
        .accessibilityLabel(title)
        .accessibilityIdentifier("ConfirmDialog")
    }

    @ViewBuilder
    private func Buttons() -> some View {
        if let cancelTitle {
            Button(action: onCancel) {
                Text(cancelTitle)
                    .modifier(ButtonLabel(foreground: .white, background: Color(.tripCardSubtext).opacity(0.25)))
            }
            .buttonStyle(.pressable)
        }
        Button(action: onConfirm) {
            confirm
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

extension ConfirmDialog where Confirm == Text {
    /// A dialog whose main button is a text, for example "Confirm" or "OK".
    init(
        title: Text,
        message: Text? = nil,
        cancelTitle: LocalizedStringResource? = .tripRoomCancel,
        confirmTitle: LocalizedStringResource,
        isDestructive: Bool = false,
        isConfirmDisabled: Bool = false,
        onCancel: @escaping () -> Void = {},
        onConfirm: @escaping () -> Void
    ) {
        self.init(
            title: title,
            message: message,
            cancelTitle: cancelTitle,
            isDestructive: isDestructive,
            isConfirmDisabled: isConfirmDisabled,
            onCancel: onCancel,
            onConfirm: onConfirm,
            confirm: { Text(confirmTitle) }
        )
    }
}

extension ConfirmDialog {
    /// The text of a dialog button, in its coloured capsule.
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

extension View {
    /// Shows a `ConfirmDialog` over this view while `isPresented` is true, fading it in and out. "Cancel" and the main
    /// button both close it; the main button runs `onConfirm` first, so the action can still read the state that
    /// opened the dialog.
    func confirmDialog<Confirm: View>(
        isPresented: Binding<Bool>,
        title: Text,
        message: Text? = nil,
        cancelTitle: LocalizedStringResource? = .tripRoomCancel,
        isDestructive: Bool = false,
        onConfirm: @escaping () -> Void,
        @ViewBuilder confirm: () -> Confirm
    ) -> some View {
        let confirmLabel = confirm()
        return overlay {
            ZStack {
                if isPresented.wrappedValue {
                    ConfirmDialog(
                        title: title,
                        message: message,
                        cancelTitle: cancelTitle,
                        isDestructive: isDestructive,
                        onCancel: { isPresented.wrappedValue = false },
                        onConfirm: {
                            onConfirm()
                            isPresented.wrappedValue = false
                        },
                        confirm: { confirmLabel }
                    )
                    .transition(.opacity)
                }
            }
            .animation(.lezgoFade, value: isPresented.wrappedValue)
        }
    }

    /// The same, with a text on the main button, for example "Confirm" or "OK".
    func confirmDialog(
        isPresented: Binding<Bool>,
        title: Text,
        message: Text? = nil,
        cancelTitle: LocalizedStringResource? = .tripRoomCancel,
        confirmTitle: LocalizedStringResource = .tripRoomConfirm,
        isDestructive: Bool = false,
        onConfirm: @escaping () -> Void
    ) -> some View {
        confirmDialog(
            isPresented: isPresented,
            title: title,
            message: message,
            cancelTitle: cancelTitle,
            isDestructive: isDestructive,
            onConfirm: onConfirm
        ) {
            Text(confirmTitle)
        }
    }
}

#if DEBUG
#Preview("Confirm") {
    Color.black.confirmDialog(
        isPresented: .constant(true),
        title: Text(verbatim: "Remove Budi from the trip?"),
        confirmTitle: .tripRoomConfirm,
        onConfirm: { }
    )
}

#Preview("Destructive with a message") {
    ConfirmDialog(
        title: Text(.tripMapEndTripQuestion),
        message: Text(.tripMapEndTripNotEveryoneMessage),
        confirmTitle: .tripMapConfirm,
        isDestructive: true,
        onConfirm: { }
    )
}

#Preview("Image button") {
    Color.black.confirmDialog(
        isPresented: .constant(true),
        title: Text(verbatim: "Start Trip?"),
        onConfirm: { },
        confirm: {
            Image(.lezgoBlack)
                .resizable()
                .scaledToFit()
                .frame(height: 22)
                .accessibilityLabel("Start")
        }
    )
}

#Preview("OK only, Accessibility XXXL") {
    ConfirmDialog(
        title: Text(.tripMapLeaderEndedTrip),
        cancelTitle: nil,
        confirmTitle: .tripRoomOK,
        onConfirm: { }
    )
    .dynamicTypeSize(.accessibility5)
}
#endif

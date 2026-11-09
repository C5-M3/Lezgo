//
//  ConfirmDialog.swift
//  Lezgo
//
//  Created by Oky Faishal on 06/11/26.
//

import SwiftUI

/// The colours of a `ConfirmDialog`. The defaults are the hi-fi: a dark card, a white title, "Cancel" in red text and
/// the main button in black on BrandYellow. Any screen can pass its own.
struct ConfirmDialogStyle {
    var titleColor: Color = .white
    var messageColor: Color = .secondary
    var background: Color = Color(uiColor: .secondarySystemBackground)
    var cancelForeground: Color = .red
    var cancelBackground: Color = Color(uiColor: .tertiarySystemBackground)
    var confirmForeground: Color = .black
    var confirmBackground: Color = Color(.brandYellow)
}

/// A confirmation drawn over a dimmed screen: a title, an optional message, "Cancel" and one main button. A system
/// alert cannot show an image on its button (the LEZGO logo) or take our colours, so every confirmation in the app
/// uses this one. Tapping outside does nothing, like a system alert: the person picks a button.
///
/// The main button's content is a view, so it can be text or an image. Without `cancelTitle` there is only the main
/// button, for messages that just say "OK".
struct ConfirmDialog<Confirm: View>: View {
    let title: Text
    let message: Text?
    let cancelTitle: LocalizedStringResource?
    let style: ConfirmDialogStyle
    let onCancel: () -> Void
    let onConfirm: () -> Void
    let confirm: Confirm

    init(
        title: Text,
        message: Text? = nil,
        cancelTitle: LocalizedStringResource? = .tripRoomCancel,
        style: ConfirmDialogStyle = ConfirmDialogStyle(),
        onCancel: @escaping () -> Void,
        onConfirm: @escaping () -> Void,
        @ViewBuilder confirm: () -> Confirm
    ) {
        self.title = title
        self.message = message
        self.cancelTitle = cancelTitle
        self.style = style
        self.onCancel = onCancel
        self.onConfirm = onConfirm
        self.confirm = confirm()
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    title
                        .font(.title3.bold())
                        .foregroundStyle(style.titleColor)
                        .accessibilityAddTraits(.isHeader)
                    if let message {
                        message
                            .font(.body)
                            .foregroundStyle(style.messageColor)
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 12) { buttons }
                    VStack(spacing: 12) { buttons }
                }
            }
            .padding(20)
            .background(style.background, in: .rect(cornerRadius: 28))
            .padding(.horizontal, 24)
            .accessibilityElement(children: .contain)
            .accessibilityLabel(title)
            .accessibilityAddTraits(.isModal)
        }
        .accessibilityAction(.escape) { cancelTitle == nil ? onConfirm() : onCancel() }
    }

    @ViewBuilder private var buttons: some View {
        if let cancelTitle {
            Button(action: onCancel) {
                Text(cancelTitle)
                    .font(.headline)
                    .foregroundStyle(style.cancelForeground)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(style.cancelBackground, in: Capsule())
            }
            .buttonStyle(.plain)
        }
        Button(action: onConfirm) {
            confirm
                .font(.headline)
                .foregroundStyle(style.confirmForeground)
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(style.confirmBackground, in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

extension View {
    /// Shows a `ConfirmDialog` over this view while `isPresented` is true. "Cancel" and the main button both close it;
    /// the main button runs `onConfirm` first, so the action can still read the state that opened the dialog.
    func confirmDialog<Confirm: View>(
        isPresented: Binding<Bool>,
        title: Text,
        message: Text? = nil,
        cancelTitle: LocalizedStringResource? = .tripRoomCancel,
        style: ConfirmDialogStyle = ConfirmDialogStyle(),
        onConfirm: @escaping () -> Void,
        @ViewBuilder confirm: () -> Confirm
    ) -> some View {
        let confirmLabel = confirm()
        return overlay {
            if isPresented.wrappedValue {
                ConfirmDialog(
                    title: title,
                    message: message,
                    cancelTitle: cancelTitle,
                    style: style,
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
    }

    /// The same, with a text on the main button, for example "Confirm" or "OK".
    func confirmDialog(
        isPresented: Binding<Bool>,
        title: Text,
        message: Text? = nil,
        cancelTitle: LocalizedStringResource? = .tripRoomCancel,
        confirmTitle: LocalizedStringResource = .tripRoomConfirm,
        style: ConfirmDialogStyle = ConfirmDialogStyle(),
        onConfirm: @escaping () -> Void
    ) -> some View {
        confirmDialog(
            isPresented: isPresented,
            title: title,
            message: message,
            cancelTitle: cancelTitle,
            style: style,
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
    .preferredColorScheme(.dark)
}

#Preview("Image button and message") {
    Color.black.confirmDialog(
        isPresented: .constant(true),
        title: Text(verbatim: "Start Trip?"),
        message: Text(verbatim: "Everyone is ready."),
        onConfirm: { },
        confirm: {
            Image(.lezgoBlack)
                .resizable()
                .scaledToFit()
                .frame(height: 22)
                .accessibilityLabel("Start")
        }
    )
    .preferredColorScheme(.dark)
}

#Preview("OK only, Accessibility XXXL") {
    Color.black.confirmDialog(
        isPresented: .constant(true),
        title: Text(verbatim: "You were removed from the trip."),
        cancelTitle: nil,
        confirmTitle: .tripRoomOK,
        onConfirm: { }
    )
    .dynamicTypeSize(.accessibility5)
    .preferredColorScheme(.dark)
}
#endif

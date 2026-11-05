//
//  StartTripDialog.swift
//  Lezgo
//
//  Created by oky faishal on 05/11/26.
//

import SwiftUI

/// The hi-fi "Start Trip?" confirmation (US-05, "Start the trip"). A system alert cannot show the LEZGO logo on its
/// button, so this is drawn over the Trip Room, which is dimmed meanwhile.
struct StartTripDialog: View {
    /// "Start Trip?", or the warning that someone is not ready yet.
    let title: String
    let onCancel: () -> Void
    let onStart: () -> Void

    var body: some View {
        ZStack {
            // Like a system alert, tapping outside does nothing: the leader picks Cancel or LEZGO.
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 16) {
                Text(title)
                    .font(.title3.bold())
                    .foregroundStyle(Color(.brandYellow))
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 12) { buttons }
                    VStack(spacing: 12) { buttons }
                }
            }
            .padding(20)
            .background(Color(uiColor: .secondarySystemBackground), in: .rect(cornerRadius: 28))
            .padding(.horizontal, 24)
            .accessibilityElement(children: .contain)
            .accessibilityAddTraits(.isModal)
        }
        .accessibilityAction(.escape, onCancel)
    }

    @ViewBuilder private var buttons: some View {
        Button(action: onCancel) {
            Text("Cancel")
                .font(.headline)
                .foregroundStyle(Color(.brandYellow))
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(Color(uiColor: .tertiarySystemBackground), in: Capsule())
        }
        .buttonStyle(.plain)
        Button(action: onStart) {
            Image(.lezgoBlack)
                .resizable()
                .scaledToFit()
                .frame(height: 22)
        }
        .buttonStyle(.yellowCapsule(minHeight: 52))
        .accessibilityLabel("Start")
    }
}

#if DEBUG
#Preview("Everyone ready") {
    StartTripDialog(title: "Start Trip?", onCancel: {}, onStart: {})
        .preferredColorScheme(.dark)
}

#Preview("Someone not ready, Accessibility XXXL") {
    StartTripDialog(
        title: "Some participants are not yet ready, are you sure you want to start the trip?",
        onCancel: {},
        onStart: {}
    )
    .dynamicTypeSize(.accessibility5)
    .preferredColorScheme(.dark)
}
#endif

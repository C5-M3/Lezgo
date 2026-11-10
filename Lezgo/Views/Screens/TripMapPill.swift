//
//  TripMapPill.swift
//  Lezgo
//
//  Created by Nathan Sudiara on 05/11/26.
//

import SwiftUI

/// The notification pill under the turn card, as in the hi-fi: dark with yellow text, or red with dark text when
/// something is wrong. Always with an icon, so it reads at a glance without colour. A tap closes it; without `onTap`
/// it cannot be closed.
struct TripMapPill: View {
    let message: Text
    var isUrgent = false
    var onTap: (() -> Void)?

    var body: some View {
        Group {
            if let onTap {
                Button(action: onTap) { Label() }
                    .buttonStyle(.plain)
                    .accessibilityHint(Text(.tripMapCloseAlert))
            } else {
                Label()
            }
        }
        // Any bigger, the banner and the turn card no longer fit above the map with the bottom card. VoiceOver still
        // reads the whole message.
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
    }

    private func Label() -> some View {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.circle.fill")
                .accessibilityHidden(true)
            message
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .font(.subheadline.bold())
        .foregroundStyle(isUrgent ? Color(.tripCard) : Color(.brandYellow))
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, minHeight: 44)
        .background(isUrgent ? Color(.tripAlertRed) : Color(.tripCard), in: .rect(cornerRadius: 22))
        .contentShape(.rect(cornerRadius: 22))
    }
}

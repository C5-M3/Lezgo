//
//  JoinTripView+FullScreen.swift
//  Lezgo
//
//  Created by Nathan Sudiara on 16/11/26.
//

import SwiftUI

/// "Enter room code" as a full screen on the split-screen Home (issue #329), with a round Back button instead of a
/// sheet that is pulled down.
extension JoinTripView {
    var isFullScreen: Bool { onClose != nil }

    /// The mascot is decoration: it leaves when the screen has no height to spare, at accessibility text sizes and
    /// when the screen is short (landscape), so the code boxes and the keyboard keep their room.
    var showsMascot: Bool {
        !textSize.isAccessibilitySize && verticalSizeClass != .compact
    }

    /// The round Back button alone at the top left, then the mascot with the phone and the title, as in the hi-fi.
    @ViewBuilder
    var fullScreenHeader: some View {
        VStack(spacing: 12) {
            HStack {
                RoundBackButton(action: Close)
                Spacer()
            }
            .padding(.horizontal, -6)

            if showsMascot {
                Image(.joinPhoneMascot)
                    .resizable()
                    .scaledToFit()
                    // It also shrinks before it pushes the boxes down, on a small screen with the keyboard up.
                    .frame(maxHeight: 240)
                    .accessibilityHidden(true)
            }

            headerSection
                .frame(maxWidth: .infinity)
        }
    }

    /// As a sheet, the keyboard comes up by itself once the sheet shows.
    func FocusSheetField() async {
        guard !isFullScreen else { return }
        // Memunculkan keyboard secara otomatis saat sheet tampil
        try? await Task.sleep(for: .milliseconds(150))
        isFieldFocused = true
    }

    /// Full screen on the split Home, the keyboard rises once Enter room code has landed, not see-through over the
    /// wipe, and drops as soon as Back starts.
    func FocusFullScreenField(canRaise: Bool) {
        guard isFullScreen else { return }
        isFieldFocused = canRaise
    }

    func Close() {
        // The keyboard goes down with the screen instead of staying over Home.
        isFieldFocused = false
        onClose?()
    }
}

#Preview("Full screen") {
    JoinTripView(isPresented: .constant(true), onClose: {})
}

#Preview("Full screen, largest text") {
    JoinTripView(isPresented: .constant(true), onClose: {})
        .dynamicTypeSize(.accessibility5)
}

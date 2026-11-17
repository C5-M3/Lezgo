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

    /// The title between a round Back button on the left and an empty space of the same width on the right. At
    /// accessibility text sizes the title needs the full width, so the Back button sits on its own row above it.
    @ViewBuilder
    var fullScreenHeader: some View {
        if textSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 12) {
                RoundBackButton(action: Close)
                    .padding(.horizontal, -6)

                headerSection
                    .frame(maxWidth: .infinity)
            }
        } else {
            HStack(alignment: .top) {
                RoundBackButton(action: Close)

                headerSection
                    .frame(maxWidth: .infinity)
                    .padding(.top, 10)

                Color.clear
                    .frame(width: 44, height: 44)
            }
            .padding(.horizontal, -6)
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

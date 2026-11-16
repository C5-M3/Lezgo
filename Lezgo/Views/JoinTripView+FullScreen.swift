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

    /// The title between a round Back button on the left and an empty space of the same width on the right.
    var fullScreenHeader: some View {
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

    func Close() {
        // The keyboard goes down with the screen instead of staying over Home.
        isFieldFocused = false
        onClose?()
    }
}

#Preview("Full screen") {
    JoinTripView(isPresented: .constant(true), onClose: {})
}

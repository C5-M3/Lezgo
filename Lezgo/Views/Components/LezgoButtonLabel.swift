//
//  LezgoButtonLabel.swift
//  Lezgo
//

import SwiftUI

/// The label of a main button that can be working: the title, or a spinner in its place.
///
/// The title stays in the layout, only invisible, so the button has the same size loading or not. The spinner is
/// black like the title, on the yellow button, and regular size: the button is drawn at the extra large control size,
/// and a plain `ProgressView` inside it follows that size and fills the button.
struct LezgoButtonLabel: View {
    let title: LocalizedStringResource
    let isLoading: Bool
    /// What VoiceOver says while loading; the title when `nil`.
    var loadingLabel: LocalizedStringResource?

    var body: some View {
        Text(title)
            .opacity(isLoading ? 0 : 1)
            .accessibilityHidden(isLoading && loadingLabel != nil)
            .overlay {
                if isLoading {
                    ProgressView()
                        .controlSize(.regular)
                        .tint(.black)
                        .accessibilityLabel(loadingLabel.map { Text($0) } ?? Text(title))
                }
            }
    }
}

#Preview("Idle and loading") {
    VStack(spacing: 16) {
        Button {} label: { LezgoButtonLabel(title: "Save", isLoading: false) }
            .lezgoGlassButton(.main)
        Button {} label: { LezgoButtonLabel(title: "Save", isLoading: true) }
            .lezgoGlassButton(.main)
    }
    .padding()
    .background(Color(.tripCard))
}

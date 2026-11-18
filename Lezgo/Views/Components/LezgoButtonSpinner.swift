//
//  LezgoButtonSpinner.swift
//  Lezgo
//

import SwiftUI

/// The spinner that takes the place of a main button's title while it works. The main button is drawn at the extra
/// large control size, and a plain `ProgressView` inside it follows that size and fills the button, so this one
/// keeps the regular size.
struct LezgoButtonSpinner: View {
    var body: some View {
        ProgressView()
            .controlSize(.regular)
    }
}

#Preview {
    Button {} label: { LezgoButtonSpinner() }
        .lezgoGlassButton(.main)
        .padding()
        .background(Color(.tripCard))
}

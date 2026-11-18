//
//  LezgoSheet.swift
//  Lezgo
//

import SwiftUI

extension View {
    /// The one look every sheet has: the page colour behind it, a drag indicator, and the card radius (ADR 0033).
    ///
    /// A solid background, not the system's glass sheet, so the glass buttons on the sheet keep their tint. A faint
    /// white line along its edge shows where the sheet starts on the black page.
    func lezgoSheet() -> some View {
        overlay {
            ConcentricRectangle()
                .stroke(Color.white.opacity(0.18), lineWidth: 1)
                .ignoresSafeArea()
                .allowsHitTesting(false)
        }
        .presentationBackground(Color(LezgoSurface.page.color))
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(LezgoRadius.card)
    }
}

#Preview {
    Color(.brandYellow)
        .ignoresSafeArea()
        .sheet(isPresented: .constant(true)) {
            Text("Sheet")
                .foregroundStyle(Color(.tripCardText))
                .presentationDetents([.medium])
                .lezgoSheet()
        }
}

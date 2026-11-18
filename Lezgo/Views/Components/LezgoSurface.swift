//
//  LezgoSurface.swift
//  Lezgo
//

import SwiftUI

/// The solid surfaces of the app, from the back to the front (ADR 0033).
///
/// A screen names a level instead of writing a grey, so every card and field of one level has the same colour.
enum LezgoSurface {
    /// Screens, sheets, and every card that floats over a map.
    case page
    /// Tiles and cards on a page, and fields on a page.
    case level1
    /// Anything that sits on a level 1 surface.
    case level2

    var color: ColorResource {
        switch self {
        case .page: .tripCard
        case .level1: .tripCardButton
        case .level2: .surfaceField
        }
    }
}

/// The corner radii the app uses. Pills and buttons are capsules and need none.
enum LezgoRadius {
    /// Cards, panels and sheets.
    static let card: CGFloat = 30
    /// Inner cards and fields.
    static let field: CGFloat = 20
    /// Small elements such as code boxes and chips.
    static let small: CGFloat = 12
}

extension View {
    /// Puts the view on a solid surface of the given level with rounded corners.
    func lezgoSurface(_ level: LezgoSurface, radius: CGFloat) -> some View {
        background(Color(level.color), in: .rect(cornerRadius: radius))
            .lezgoCardEdge(isShown: radius >= LezgoRadius.card)
    }

    /// A very faint white edge that shows where a card or dialog ends on the black page (ADR 0033).
    func lezgoCardEdge(isShown: Bool = true) -> some View {
        shadow(color: .white.opacity(isShown ? 0.07 : 0), radius: 1.5)
    }
}

#Preview("Levels") {
    VStack(spacing: 16) {
        Text("Level 2 on level 1")
            .padding()
            .lezgoSurface(.level2, radius: LezgoRadius.small)
            .padding()
            .frame(maxWidth: .infinity)
            .lezgoSurface(.level1, radius: LezgoRadius.field)
    }
    .foregroundStyle(Color(.tripCardText))
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color(.tripCard))
}

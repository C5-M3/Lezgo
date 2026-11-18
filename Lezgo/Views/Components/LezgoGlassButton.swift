//
//  LezgoGlassButton.swift
//  Lezgo
//

import SwiftUI

/// What a button is for. The role decides its tint, its text colour and its smallest size (ADR 0032).
enum LezgoGlassRole {
    /// The one thing the driver is expected to do next: Start Trip, Enter, Save.
    case main
    /// A quiet second action: New Trip, Edit Route, Cancel.
    case second
    /// An action that ends or removes something: End Trip, Exit Trip, Remove.
    case destructive
    /// A round icon button: Back, camera, sound.
    case round
    /// A round icon button on the yellow half of Home. Plain glass takes the yellow and turns pale, so this one is
    /// tinted black.
    case roundOnYellow

    /// The tint of the glass: the main role is yellow, the one on yellow is black. Every other role is the system's
    /// plain glass.
    var tint: ColorResource? {
        switch self {
        case .main: .brandYellow
        case .roundOnYellow: .tripCard
        case .second, .destructive, .round: nil
        }
    }

    var isRound: Bool { self == .round || self == .roundOnYellow }

    var textColor: Color {
        switch self {
        case .main: .black
        case .second, .round, .roundOnYellow: Color(.tripCardText)
        case .destructive: Color(.tripAlertRed)
        }
    }

    var minimumHeight: CGFloat { isRound ? 44 : 56 }

    /// Only the round role has a smallest width; the others take the width they are given.
    var minimumWidth: CGFloat? { isRound ? 44 : nil }
}

/// Gives a button the system's own Liquid Glass style for its role.
///
/// Native on purpose: `.glass` for every button, and `.glassProminent` tinted yellow for the main one. The system
/// draws the press effect, the disabled look and the Reduce Transparency fallback. We only set the size and the
/// text colour.
private struct LezgoGlassButtonModifier: ViewModifier {
    let role: LezgoGlassRole
    let side: CGFloat?
    let isWorking: Bool

    func body(content: Content) -> some View {
        switch role {
        case .main where isWorking:
            // Plain glass, not yellow, so the yellow spinner shows on it.
            content
                .buttonStyle(.glass)
                .foregroundStyle(role.textColor)
                .modifier(CapsuleSize())
        case .main:
            content
                .buttonStyle(.glassProminent)
                .tint(Color(.brandYellow))
                .foregroundStyle(role.textColor)
                .modifier(CapsuleSize())
        case .second, .destructive:
            content
                .buttonStyle(.glass)
                .foregroundStyle(role.textColor)
                .modifier(CapsuleSize())
        case .round, .roundOnYellow:
            content.buttonStyle(RoundGlassButtonStyle(role: role, side: side))
        }
    }
}

/// A round glass button of a fixed size. The system's `.glass` style only grows to its label, so the circle is drawn
/// with `glassEffect`. It is a style, not a modifier on the view, so a group of buttons gets one circle each.
private struct RoundGlassButtonStyle: ButtonStyle {
    let role: LezgoGlassRole
    let side: CGFloat?

    @Environment(\.isEnabled) private var isEnabled

    private var glass: Glass {
        let plain = Glass.regular.tint(role.tint.map { Color($0) })
        return isEnabled ? plain.interactive() : plain
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(role.textColor)
            .frame(width: side ?? role.minimumWidth, height: side ?? role.minimumHeight)
            .glassEffect(glass, in: .circle)
            .contentShape(.circle)
            .opacity(isEnabled ? 1 : 0.5)
            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
    }
}

/// A capsule button as wide as it is given, at the system's extra large height.
private struct CapsuleSize: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.headline)
            .buttonBorderShape(.capsule)
            .buttonSizing(.flexible)
            .controlSize(.extraLarge)
            .dynamicTypeSize(...DynamicTypeSize.accessibility5)
    }
}

extension View {
    /// Draws the buttons in this view with the system's glass style for the given role.
    ///
    /// A round button can be larger than 44 points with `side`, as the trip map's controls are.
    ///
    /// `isWorking` turns a main button into plain glass while it works (see `LezgoButtonLabel`).
    func lezgoGlassButton(_ role: LezgoGlassRole, side: CGFloat? = nil, isWorking: Bool = false) -> some View {
        modifier(LezgoGlassButtonModifier(role: role, side: side, isWorking: isWorking))
    }

    /// Puts a tappable view that holds a picture on tinted glass. Apply it after padding and frame.
    func lezgoGlass(role: LezgoGlassRole, in shape: some Shape) -> some View {
        glassEffect(role.tint.map { Glass.regular.tint(Color($0)).interactive() } ?? .regular.interactive(), in: shape)
    }
}

#Preview("Roles") {
    VStack(spacing: 16) {
        Button("Start Trip") {}.lezgoGlassButton(.main)
        Button("Start Trip") {}.lezgoGlassButton(.main).disabled(true)
        Button("New Trip") {}.lezgoGlassButton(.second)
        Button("End Trip") {}.lezgoGlassButton(.destructive)
        Button("Back", systemImage: "chevron.left") {}
            .labelStyle(.iconOnly)
            .lezgoGlassButton(.round)
    }
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color(.tripCard))
}

#Preview("On a level 1 card, largest text") {
    VStack(spacing: 16) {
        Button("New Trip") {}.lezgoGlassButton(.second)
        Button("End Trip for Everyone") {}.lezgoGlassButton(.destructive)
    }
    .padding()
    .lezgoSurface(.level1, radius: LezgoRadius.card)
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color(.tripCard))
    .dynamicTypeSize(.accessibility5)
}

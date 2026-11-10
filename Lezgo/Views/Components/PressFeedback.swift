//
//  PressFeedback.swift
//  Lezgo
//
//  Created by Nathan Sudiara on 09/11/26.
//

import SwiftUI

/// How every custom button answers a press: it dims and shrinks a little, then springs back, so a tap is felt even
/// while the eyes are on the road. With Reduce Motion it only dims.
struct PressFeedback: ViewModifier {
    let isPressed: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .opacity(isPressed ? 0.75 : 1)
            .scaleEffect(isPressed && reduceMotion == false ? 0.96 : 1)
            .animation(.lezgoPress, value: isPressed)
    }
}

extension View {
    /// Dims and shrinks the view while `isPressed`, for use inside a `ButtonStyle`.
    func pressFeedback(isPressed: Bool) -> some View {
        modifier(PressFeedback(isPressed: isPressed))
    }
}

/// A button that draws its own label, as `.plain` does, but still answers a press.
struct PressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .pressFeedback(isPressed: configuration.isPressed)
    }
}

extension ButtonStyle where Self == PressableButtonStyle {
    static var pressable: PressableButtonStyle { PressableButtonStyle() }
}

#Preview("Pressable") {
    Button("Press and hold") {}
        .buttonStyle(.pressable)
        .padding()
}

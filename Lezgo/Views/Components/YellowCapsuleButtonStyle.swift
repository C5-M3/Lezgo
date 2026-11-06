//
//  YellowCapsuleButtonStyle.swift
//  Lezgo
//
//  Created by Oky Faishal on 05/11/26.
//

import SwiftUI

/// The main action of a dark screen: black text on a BrandYellow capsule. A disabled button fades instead of
/// disappearing, so the leader can still see it is there, or takes `disabledBackground` when a screen wants one.
struct YellowCapsuleButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    var minHeight: CGFloat = 56
    var disabledBackground: Color?

    private var background: Color {
        if isEnabled { return Color(.brandYellow) }
        return disabledBackground ?? Color(.brandYellow).opacity(0.4)
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity, minHeight: minHeight)
            .background(background, in: Capsule())
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}

extension ButtonStyle where Self == YellowCapsuleButtonStyle {
    static var yellowCapsule: YellowCapsuleButtonStyle { YellowCapsuleButtonStyle() }
    static func yellowCapsule(minHeight: CGFloat = 56, disabledBackground: Color? = nil) -> YellowCapsuleButtonStyle {
        YellowCapsuleButtonStyle(minHeight: minHeight, disabledBackground: disabledBackground)
    }
}

#if DEBUG
#Preview("Enabled and disabled") {
    VStack(spacing: 16) {
        Button("Start Trip") { }
        Button("Start Trip") { }.disabled(true)
    }
    .buttonStyle(.yellowCapsule)
    .padding()
    .background(.black)
}
#endif

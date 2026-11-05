//
//  YellowCapsuleButtonStyle.swift
//  Lezgo
//
//  Created by Oky Faishal on 05/11/26.
//

import SwiftUI

/// The main action of a dark screen: black text on a BrandYellow capsule. A disabled button fades instead of
/// disappearing, so the leader can still see it is there.
struct YellowCapsuleButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    var minHeight: CGFloat = 56

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity, minHeight: minHeight)
            .background(Color(.brandYellow).opacity(isEnabled ? 1 : 0.4), in: Capsule())
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}

extension ButtonStyle where Self == YellowCapsuleButtonStyle {
    static var yellowCapsule: YellowCapsuleButtonStyle { YellowCapsuleButtonStyle() }
    static func yellowCapsule(minHeight: CGFloat) -> YellowCapsuleButtonStyle {
        YellowCapsuleButtonStyle(minHeight: minHeight)
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

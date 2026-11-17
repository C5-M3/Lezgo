//
//  HomeSplitSwingVisibility.swift
//  Lezgo
//
//  Created by Nathan Sudiara on 17/11/26.
//

import SwiftUI

/// Hides part of a yellow layer of the split-screen Home (issue #329) while the yellow swings as one sheet. Both
/// yellow layers are cut to the same sheet then: the LEAD layer gives the yellow and the lead mascot, and the JOIN
/// layer, without its own yellow, puts the logo, the words and the crew on top. Drawing the logo and the words once
/// keeps their edges as crisp as on the homes.
struct HomeSplitSwingVisibility: ViewModifier, Animatable {
    let flow: HomeSplitMotion.Flow
    var progress: Double
    /// `false` for the parts that stay on screen during the Swing.
    let hidesWhileSwinging: Bool

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func body(content: Content) -> some View {
        content.opacity(hidesWhileSwinging && HomeSplitMotion.IsSwinging(flow, progress: progress) ? 0 : 1)
    }
}

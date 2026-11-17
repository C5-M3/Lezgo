//
//  EnvironmentValues+CanRaiseKeyboard.swift
//  Lezgo
//
//  Created by Nathan Sudiara on 17/11/26.
//

import SwiftUI

extension EnvironmentValues {
    /// `false` while a screen is built ahead and hidden, or still moving in: a text field in it must not take focus
    /// then, or the keyboard would rise over the screen before it. The split-screen Home (issue #329) sets it for Set
    /// Route and Enter room code; it turns `true` once they have landed, and the field asks for focus again then.
    @Entry var canRaiseKeyboard = true
}

//
//  EnvironmentValues+CarPlaySession.swift
//  Lezgo
//
//  Created by Oky Faishal on 18/11/26.
//

import SwiftUI

extension EnvironmentValues {
    /// Whether CarPlay is connected (ADR 0034). The app shares one, because UIKit creates the CarPlay scene delegate
    /// itself; previews and tests make their own.
    @Entry var carPlaySession = CarPlaySession.shared
}

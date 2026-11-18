//
//  CarPlaySession.swift
//  Lezgo
//
//  Created by Oky Faishal on 18/11/26.
//

import Foundation
import Observation

/// Whether CarPlay is connected (ADR 0034).
///
/// The CarPlay scene delegate sets it. The trip map reads it to decide between the map and the On the Go list on the
/// phone.
@Observable
final class CarPlaySession {
    /// The one the app uses. UIKit creates the CarPlay scene delegate itself, so it cannot be handed one; tests and
    /// previews make their own.
    static let shared = CarPlaySession()

    private(set) var isConnected = false

    func Connected() {
        isConnected = true
    }

    func Disconnected() {
        isConnected = false
    }
}

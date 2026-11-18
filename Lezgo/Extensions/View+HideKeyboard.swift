//
//  View+HideKeyboard.swift
//  Lezgo
//

import SwiftUI

extension View {
    /// Closes the system keyboard (resigns the first responder).
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

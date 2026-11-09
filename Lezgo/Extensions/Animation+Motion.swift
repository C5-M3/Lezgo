//
//  Animation+Motion.swift
//  Lezgo
//
//  Created by Nathan Sudiara on 09/11/26.
//

import SwiftUI

/// The few animations every screen shares, so the same kind of change moves the same way everywhere.
extension Animation {
    /// Content that changes in place: a card swapping for another, a banner coming or going, a number changing.
    static let lezgoSwap = Animation.smooth(duration: 0.3)
    /// Something the finger opens or closes, such as the trip map's bottom card or a list of stops.
    static let lezgoPanel = Animation.spring(duration: 0.4, bounce: 0.15)
    /// A dialog or menu that comes in over the screen: a little bounce so it reads as arriving, not blinking.
    static let lezgoDialog = Animation.spring(duration: 0.35, bounce: 0.2)
    /// A pressed button shrinking and coming back.
    static let lezgoPress = Animation.snappy(duration: 0.2)
    /// A plain fade, the replacement for motion while Reduce Motion is on.
    static let lezgoFade = Animation.easeInOut(duration: 0.2)

    /// `nil` while Reduce Motion is on, so the change happens at once instead of moving.
    func Respecting(reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : self
    }
}

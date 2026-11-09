//
//  TripMapViewModel+Sound.swift
//  Lezgo
//
//  Created by Nathan Sudiara on 09/11/26.
//

import Foundation

// Voice guidance and alert sounds (`specs/UserStories.md` → US-06, "Sound", ADR 0024).
extension TripMapViewModel {
    /// Speaks what is new: the next turn, a new banner or a new notice. A closed map says nothing.
    func Announce() {
        guard closeReason == nil else {
            sound.Stop()
            return
        }
        sound.Update(guidance: guidance, banner: alertBanner, notice: noticeBanner)
    }
}

//
//  TripMapViewModel+Notices.swift
//  Lezgo
//
//  Created by Nathan Sudiara on 05/11/26.
//

import Foundation

// The banners about the route and an offline leader (`specs/UserStories.md` → US-06, "Route changes" and "Leader
// offline").
extension TripMapViewModel {
    /// A tap on a notice, or the end of its time on screen.
    func DismissNotice(_ notice: TripMapNotice) {
        notices.Close(notice)
    }
}

//
//  TripMapViewModel+Notices.swift
//  Lezgo
//
//  Created by Nathan Sudiara on 05/11/26.
//

import Foundation

// The banners about the route and the leader (`specs/UserStories.md` → US-06, "Route changes" and "Leader offline").
extension TripMapViewModel {
    func DismissNotice(_ notice: TripMapNotice) {
        notices.Close(notice)
    }

    /// With the leader gone for 5 minutes and nobody else left, this phone takes over without asking: the driver must
    /// not have to choose anything on the road. It tries once, and the save only works if the leader has not changed.
    func TakeOverIfOnlyMemberLeft() async {
        guard notices.hasTriedTakeOver == false, let state,
              TripMapNotices.ShouldTakeOver(state, me: myParticipantID, at: updatedAt ?? .now),
              let leaderID = state.leader?.id else { return }
        notices.hasTriedTakeOver = true
        try? await tripService.SetLeader(myParticipantID, tripID: tripID, replacing: leaderID)
    }
}

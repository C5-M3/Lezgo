//
//  TripMapViewModel+Seat.swift
//  Lezgo
//
//  Created by Oky Faishal on 16/11/26.
//

import Foundation

extension TripMapViewModel {
    /// Follows the trip until it closes on this phone, and watches that no other phone of this iCloud account takes
    /// this phone's place meanwhile (ADR 0031). Either one ending ends both.
    func FollowTripAndSeat() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.FollowTrip() }
            group.addTask { await self.FollowSeat() }
            await group.next()
            group.cancelAll()
        }
    }

    /// When another phone of this iCloud account takes this phone's place, this phone stops moving the car at once
    /// and forgets the trip; the other phone is the one in it now (ADR 0031).
    private func FollowSeat() async {
        await tripService.SeatTakenOver(tripID: tripID)
        guard Task.isCancelled == false, closeReason == nil else { return }
        locationSharer?.Stop()
        activeTripStorage?.ClearActiveTrip()
        leaveConfirmation = nil
        closeReason = .takenOver
    }

    /// What the map says before it closes because of something another phone did, or `nil` when it did not close
    /// that way.
    var closedElsewhereMessage: LocalizedStringResource? {
        switch closeReason {
        case .endedByLeader: .tripMapLeaderEndedTrip
        case .removed: .tripMapRemovedFromTrip
        case .takenOver: .tripSeatTakenOver
        case .backToTripRoom, .exited, .ended, nil: nil
        }
    }
}

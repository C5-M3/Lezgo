//
//  TripRecapDetailViewModel.swift
//  Lezgo
//
//  Created by Rizal Pratama on 16/11/26.
//

import Foundation
import MapKit
import Observation

@Observable
@MainActor
final class TripRecapDetailViewModel {
    let recap: TripRecap
    private(set) var shareImage: TripRecapShareImage?
    private(set) var isShareFailed = false
    private(set) var isPreparingShareImage = false

    init(recap: TripRecap) {
        self.recap = recap
    }

    var title: String {
        recap.formattedDate
    }

    var destinationName: String {
        recap.destinationName
    }

    var startPointName: String {
        recap.resolvedStartPointName
    }

    var stopsCount: Int {
        recap.resolvedStopsCount
    }

    var timeSpentText: String {
        recap.resolvedDurationText
    }

    var totalDistanceText: String {
        recap.distanceText
    }

    var participants: [TripRecapParticipant] {
        recap.resolvedParticipants
    }

    var polyline: [Coordinate] {
        recap.polyline
    }

    var startCoordinate: Coordinate {
        recap.startCoordinate
    }

    var destinationCoordinate: Coordinate {
        recap.destinationCoordinate
    }

    var boundingRect: MKMapRect {
        recap.boundingRect
    }

    var leaderAvatar: Avatar {
        participants.first(where: \.isLeader)?.avatar ?? recap.avatars.first ?? .yellow
    }

    var shareCardContent: TripRecapShareCardContent {
        TripRecapShareCardContent(recap: recap)
    }

    /// Makes the picture that the share button sends. `make` is the real renderer in the app and a fake in tests.
    func PrepareShareImage(using make: (TripRecap) async -> TripRecapShareImage?) async {}

    var shareSummary: String {
        """
        Trip Recap: \(destinationName)
        Date: \(title)
        Starting Point: \(startPointName)
        Destination: \(destinationName)
        Stops: \(stopsCount)
        Time Spent: \(timeSpentText)
        Total Distance: \(totalDistanceText)
        Participants: \(participants.map(\.displayName).joined(separator: ", "))
        Shared with Lezgo
        """
    }
}

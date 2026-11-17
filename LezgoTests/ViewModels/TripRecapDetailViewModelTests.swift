//
//  TripRecapDetailViewModelTests.swift
//  LezgoTests
//
//  Created by Rizal Pratama on 16/11/26.
//

import Foundation
import Testing
@testable import Lezgo

@MainActor
struct TripRecapDetailViewModelTests {
    @Test("TripRecapDetailViewModel loads properties correctly from TripRecap")
    func loadsPropertiesFromRecap() {
        let sample = TripRecap.sample
        let viewModel = TripRecapDetailViewModel(recap: sample)

        #expect(viewModel.title == "8 October 2026")
        #expect(viewModel.destinationName == "Tunjungan Plaza")
        #expect(viewModel.startPointName == "Universitas Ciputra")
        #expect(viewModel.stopsCount == 6)
        #expect(viewModel.timeSpentText == "4h 18m")
        #expect(viewModel.totalDistanceText == "60 km")
        #expect(viewModel.participants.count == 3)
        #expect(viewModel.leaderAvatar == .yellow)
        #expect(viewModel.participants[0].displayName == "Agus")
        #expect(viewModel.participants[0].isLeader == true)
        #expect(viewModel.participants[1].displayName == "Budi")
        #expect(viewModel.participants[1].isLeader == false)
    }

    @Test("TripRecapDetailViewModel shareSummary contains essential trip information")
    func shareSummaryContainsDetails() {
        let sample = TripRecap.sample
        let viewModel = TripRecapDetailViewModel(recap: sample)
        let summary = viewModel.shareSummary

        #expect(summary.contains("Tunjungan Plaza"))
        #expect(summary.contains("8 October 2026"))
        #expect(summary.contains("Universitas Ciputra"))
        #expect(summary.contains("60 km"))
        #expect(summary.contains("Agus"))
    }

    @Test("TripRecap fallbacks work gracefully when new fields are nil")
    func recapFallbacks() {
        let legacyRecap = TripRecap(
            id: UUID(),
            destinationName: "Grand City",
            destinationLabel: "Grand City",
            date: Date(),
            participantCount: 2,
            distanceText: "10 km",
            avatars: [.yellow, .green],
            startCoordinate: Coordinate(latitude: -7.28, longitude: 112.74),
            destinationCoordinate: Coordinate(latitude: -7.26, longitude: 112.75),
            polyline: []
        )

        let viewModel = TripRecapDetailViewModel(recap: legacyRecap)

        #expect(viewModel.startPointName == "Starting Point")
        #expect(viewModel.stopsCount == 0)
        #expect(viewModel.timeSpentText == "–")
        #expect(viewModel.totalDistanceText == "10 km")
        #expect(viewModel.participants.count == 2)
        #expect(viewModel.leaderAvatar == .yellow)
    }

    @Test("TripRecap initializes correctly from TripState with durations and stops")
    func recapFromTripState() {
        let state = SampleTrip.State(status: .ended)
        let recap = TripRecap(state: state)

        #expect(recap != nil)
        guard let recap else { return }

        #expect(recap.destinationName == "Pakuwon mall")
        #expect(recap.startPointName == "Tunjungan Plaza")
        #expect(recap.numberOfStops == 1) // Ciputra World checkpoint
        #expect(recap.participants?.count == 5)
        #expect(recap.participants?.first?.isLeader == true)
        #expect(recap.participants?.first?.displayName == "Agus")
    }

    @Test("Participant avatars dynamically follow TripRecap avatars")
    func participantAvatarsDynamicallyFollowTripRecapData() {
        let recap = TripRecap(
            id: UUID(),
            destinationName: "Batu",
            destinationLabel: "Batu Secret Zoo",
            date: Date(),
            participantCount: 3,
            distanceText: "85 km",
            avatars: [.blue, .purple, .green],
            startCoordinate: Coordinate(latitude: -7.9, longitude: 112.5),
            destinationCoordinate: Coordinate(latitude: -7.8, longitude: 112.4),
            polyline: [],
            participants: [
                TripRecapParticipant(
                    id: UUID(),
                    displayName: "Agus",
                    carDescription: "Avanza",
                    avatar: .yellow,
                    isLeader: true
                ),
                TripRecapParticipant(
                    id: UUID(),
                    displayName: "Budi",
                    carDescription: "Brio",
                    avatar: .yellow,
                    isLeader: false
                ),
                TripRecapParticipant(
                    id: UUID(),
                    displayName: "Citra",
                    carDescription: "Jazz",
                    avatar: .yellow,
                    isLeader: false
                )
            ]
        )

        let viewModel = TripRecapDetailViewModel(recap: recap)
        #expect(viewModel.participants.count == 3)
        #expect(viewModel.participants[0].avatar == .blue)
        #expect(viewModel.participants[1].avatar == .purple)
        #expect(viewModel.participants[2].avatar == .green)
        #expect(viewModel.leaderAvatar == .blue)
    }

    @Test("Participant avatars vary dynamically when all avatars are identical")
    func participantAvatarsVaryWhenInitialAvatarsAreUniform() {
        let recap = TripRecap(
            id: UUID(),
            destinationName: "Malang",
            destinationLabel: "Alun-Alun",
            date: Date(),
            participantCount: 4,
            distanceText: "90 km",
            avatars: [.yellow, .yellow, .yellow, .yellow],
            startCoordinate: Coordinate(latitude: -7.9, longitude: 112.5),
            destinationCoordinate: Coordinate(latitude: -7.8, longitude: 112.4),
            polyline: []
        )

        let viewModel = TripRecapDetailViewModel(recap: recap)
        let resolved = viewModel.participants
        #expect(resolved.count == 4)
        let uniqueAvatars = Set(resolved.map(\.avatar))
        #expect(uniqueAvatars.count > 1)
        #expect(resolved[0].avatar == .yellow)
        #expect(resolved[1].avatar == .blue)
        #expect(resolved[2].avatar == .green)
        #expect(resolved[3].avatar == .pink)
    }
}

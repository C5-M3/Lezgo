//
//  TripCarEntity.swift
//  Lezgo
//
//  Created by Nathan Sudiara on 12/11/26.
//

import AppIntents
import Foundation

/// A car in the trip on the road, so Siri understands "Where's Budi in Lezgo" (US-08).
struct TripCarEntity: AppEntity, Identifiable {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Car"
    static let defaultQuery = TripCarQuery()

    let id: UUID
    /// The name the group sees: the driver's name, or "Leader" / "Car 3" when they typed none.
    let name: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }

    /// Every car on the open trip map, this phone's own car last so Siri suggests the others first.
    static func CarsOnTheRoad(in activeTripMap: ActiveTripMap = .shared) -> [TripCarEntity] {
        guard let answers = SiriTripMap.Current(in: activeTripMap)?.answers else { return [] }
        let cars = answers.state.participants
        let others = cars.filter { $0.id != answers.myParticipantID }
        let mine = cars.filter { $0.id == answers.myParticipantID }
        return (others + mine).map { TripCarEntity(id: $0.id, name: answers.state.DisplayName(of: $0)) }
    }
}

/// Finds the cars of the open trip, by ID or by name.
struct TripCarQuery: EntityStringQuery {
    @MainActor
    func entities(for identifiers: [UUID]) async throws -> [TripCarEntity] {
        TripCarEntity.CarsOnTheRoad().filter { identifiers.contains($0.id) }
    }

    @MainActor
    func entities(matching string: String) async throws -> [TripCarEntity] {
        TripCarEntity.CarsOnTheRoad().filter { $0.name.localizedStandardContains(string) }
    }

    @MainActor
    func suggestedEntities() async throws -> [TripCarEntity] {
        TripCarEntity.CarsOnTheRoad()
    }
}

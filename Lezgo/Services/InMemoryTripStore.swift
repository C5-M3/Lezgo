//
//  InMemoryTripStore.swift
//  Lezgo
//
//  Created by Nathan Sudiara on 26/10/26.
//

import Foundation

/// The trips an `InMemoryTripService` keeps, like a tiny server in memory.
///
/// Several services can share one store to act as several phones in one trip: give each its own iCloud user ID.
final class InMemoryTripStore {
    private(set) var trips: [UUID: TripState] = [:]
    private var listeners: [UUID: [UUID: AsyncStream<TripState>.Continuation]] = [:]

    init(trips: [TripState] = []) {
        for state in trips {
            self.trips[state.trip.id] = state
        }
    }

    /// Stores the trip and sends it to everyone listening to it.
    func Save(_ state: TripState) {
        trips[state.trip.id] = state
        for continuation in listeners[state.trip.id, default: [:]].values {
            continuation.yield(state)
        }
    }

    /// The trip right away (when it exists), then again after every `Save`, until the listener stops.
    func Listen(tripID: UUID) -> AsyncStream<TripState> {
        let (stream, continuation) = AsyncStream.makeStream(of: TripState.self)
        let listenerID = UUID()
        listeners[tripID, default: [:]][listenerID] = continuation
        let stopListening: @MainActor () -> Void = { [weak self] in
            self?.listeners[tripID]?[listenerID] = nil
        }
        continuation.onTermination = { _ in
            Task { @MainActor in stopListening() }
        }
        if let state = trips[tripID] {
            continuation.yield(state)
        }
        return stream
    }
}

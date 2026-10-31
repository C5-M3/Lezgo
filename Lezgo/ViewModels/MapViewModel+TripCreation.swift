//
//  MapViewModel+TripCreation.swift
//  Lezgo
//
//  Created by Farrell Sudjatmiko on 30/10/26.
//

import Foundation

extension MapViewModel {
    /// Creates a trip in `LOBBY` with the current route plan, registers the current user as leader,
    /// saves the summary to active trip storage, and stores the session in `createdSession`.
    @discardableResult
    func CreateTrip(
        using service: (any TripService)? = nil,
        profile: ParticipantProfile? = nil
    ) async throws -> TripSession {
        guard !isCreatingTrip else {
            throw TripServiceError.notAllowed
        }
        guard let plan = MakeTripPlan(), plan.isValid else {
            errorMessage = String(localized: TripServiceError.notAllowed.message)
            throw TripServiceError.notAllowed
        }

        isCreatingTrip = true
        defer { isCreatingTrip = false }

        let activeService = service ?? tripService
        do {
            let session = try await activeService.CreateTrip(
                plan: plan,
                profile: profile ?? profileStorage.LoadProfile()
            )
            let distanceStr = totalDistance > 0 ? String(format: "%.1f km", totalDistance / 1000) : nil
            let summary = ActiveTripSummary.From(session: session, distanceText: distanceStr)
            activeTripStorage.SaveActiveTrip(summary)
            createdSession = session
            errorMessage = nil
            return session
        } catch {
            let serviceError = TripServiceError(cloudKitError: error)
            errorMessage = String(localized: serviceError.message)
            throw error
        }
    }
}

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
                plan: await NamingStartPoint(of: plan),
                profile: profile ?? profileStorage.LoadProfile()
            )
            let distanceStr = totalDistance > 0 ? String(format: "%.1f km", totalDistance / 1000) : nil
            let summary = ActiveTripSummary.From(
                session: session,
                distanceText: distanceStr,
                estimatedDuration: totalDuration > 0 ? totalDuration : nil
            )
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

    /// The plan with its start point named after the real place. "Current Location" only means something on the
    /// leader's own planner; in the Trip Room it would leave the members wondering where to go. A place the map has
    /// no name for must not stop the trip, so it gets a general name instead.
    private func NamingStartPoint(of plan: TripPlan) async -> TripPlan {
        guard let start = plan.waypoints.first, start.name == String(localized: .waypointCurrentLocation) else {
            return plan
        }
        let placeName = try? await streetNameService.StreetName(at: start.coordinate)
        var named = plan
        named.waypoints[0].name = placeName ?? String(localized: .waypointLeaderStart)
        return named
    }
}

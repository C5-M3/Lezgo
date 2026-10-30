//
//  JoinTripViewModel.swift
//  Lezgo
//
//  Created by Rizal Pratama on 25/10/26.
//

import Foundation
import Observation
import SwiftUI

/// ViewModel untuk mengelola status input kode ruangan pada modal Join Trip.
@Observable
final class JoinTripViewModel {
    // MARK: - State Properties

    var roomCode: String = "" {
        didSet {
            // Hanya memperbolehkan angka (0-9) dan membatasi maksimal 6 digit
            let digitsOnly = roomCode.filter { $0.isNumber }
            if digitsOnly.count > 6 {
                roomCode = String(digitsOnly.prefix(6))
            } else if roomCode != digitsOnly {
                roomCode = digitsOnly
            }
            if errorMessage != nil {
                errorMessage = nil
            }
        }
    }

    var isSubmitting: Bool = false
    var errorMessage: String?
    private(set) var joinedSession: TripSession?

    // MARK: - Dependencies

    private var tripService: any TripService
    private let storage: any ActiveTripStorage
    private let hasCustomService: Bool

    // MARK: - Computed Properties

    /// Memeriksa apakah format kode ruangan sudah valid (tepat 6 digit angka).
    var isValidCode: Bool {
        roomCode.count == 6 && roomCode.allSatisfy { $0.isNumber }
    }

    // MARK: - Initializer

    init(
        roomCode: String = "",
        tripService: (any TripService)? = nil,
        storage: (any ActiveTripStorage)? = nil
    ) {
        let digitsOnly = roomCode.filter { $0.isNumber }
        self.roomCode = String(digitsOnly.prefix(6))
        self.hasCustomService = tripService != nil
        self.tripService = tripService ?? InMemoryTripService.fallback
        self.storage = storage ?? UserDefaultsActiveTripStorage()
    }

    // MARK: - Dependency Configuration

    /// Memperbarui tripService dari environment SwiftUI jika belum di-inject secara manual.
    func setTripServiceIfNeeded(_ service: any TripService) {
        if !hasCustomService {
            self.tripService = service
        }
    }

    // MARK: - Actions

    /// Mereset nilai input kode ruangan dan pesan error.
    func reset() {
        roomCode = ""
        errorMessage = nil
        isSubmitting = false
        joinedSession = nil
    }

    /// Mengirimkan dan memvalidasi kode ruangan ke database.
    @discardableResult
    func submitCode() async -> Bool {
        guard isValidCode else {
            errorMessage = String(localized: "Room code must be 6 digits")
            return false
        }

        isSubmitting = true
        errorMessage = nil
        joinedSession = nil

        defer {
            isSubmitting = false
        }

        do {
            let session = try await tripService.JoinTrip(roomCode: roomCode, profile: nil)

            // A LOBBY trip opens the Trip Room and an IN_TRIP trip opens the map for a late member (US-02); the
            // service already turns away ended and cancelled trips.
            let summary = ActiveTripSummary.From(session: session)
            storage.SaveActiveTrip(summary)
            self.joinedSession = session
            return true
        } catch let error as TripServiceError {
            switch error {
            case .notFound:
                errorMessage = String(localized: .tripServiceErrorNotFound)
            case .tripEnded:
                errorMessage = String(localized: .tripServiceErrorTripEnded)
            default:
                errorMessage = String(localized: error.message)
            }
            return false
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}

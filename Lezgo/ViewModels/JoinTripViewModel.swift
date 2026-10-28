//
//  JoinTripViewModel.swift
//  Lezgo
//
//  Created by Rizal Pratama on 25/10/26.
//

import Foundation
import SwiftUI

/// ViewModel untuk mengelola status input kode ruangan pada modal Join Trip.
@Observable
@MainActor
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
        }
    }

    var isSubmitting: Bool = false
    var errorMessage: String?

    // MARK: - Computed Properties

    /// Memeriksa apakah format kode ruangan sudah valid (tepat 6 digit angka).
    var isValidCode: Bool {
        roomCode.count == 6 && roomCode.allSatisfy { $0.isNumber }
    }

    // MARK: - Initializer

    init(roomCode: String = "") {
        let digitsOnly = roomCode.filter { $0.isNumber }
        self.roomCode = String(digitsOnly.prefix(6))
    }

    // MARK: - Actions

    /// Mereset nilai input kode ruangan dan pesan error.
    func reset() {
        roomCode = ""
        errorMessage = nil
        isSubmitting = false
    }

    /// Mengirimkan dan memvalidasi kode ruangan.
    func submitCode() async -> Bool {
        guard isValidCode else {
            errorMessage = "Kode ruangan harus terdiri dari 6 digit angka"
            return false
        }

        isSubmitting = true
        errorMessage = nil

        // Simulasi delay validasi kode ruangan
        try? await Task.sleep(nanoseconds: 200_000_000)
        isSubmitting = false
        return true
    }
}

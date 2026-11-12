//
//  JoinTripIntent.swift
//  Lezgo
//
//  Created by Nathan Sudiara on 12/11/26.
//

import AppIntents
import Foundation

/// "Join a trip in Lezgo" (US-08): asks for the room code, joins right away like "Enter" in the join dialog, and
/// opens the Trip Room. A wrong code is spoken with the join dialog's own message.
struct JoinTripIntent: AppIntent {
    static let title: LocalizedStringResource = "Join a Trip"
    static let description = IntentDescription("Joins a Lezgo trip with its room code and opens the Trip Room.")
    /// The app comes to the front before `perform` runs, so the Trip Room opens when Siri finishes.
    static let supportedModes: IntentModes = .foreground(.immediate)

    @Parameter(
        title: "Room Code",
        inputOptions: String.IntentInputOptions(keyboardType: .numberPad),
        requestValueDialog: "What's the room code?"
    )
    var code: String

    init() {}

    init(code: String) {
        self.code = code
    }

    /// How joining went.
    enum Outcome: Equatable {
        case joined(TripSession)
        /// The join dialog's message, for example "No trip found with this code."
        case failed(String)
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let roomCode = SpokenRoomCode.Parse(code) else {
            throw $code.needsValueError(IntentDialog(stringLiteral: String(localized: .siriRoomCodeInvalid)))
        }
        guard SiriTripMap.HasTripOnThisPhone() == false else { throw SiriRefusal.alreadyInTrip }
        switch await Self.Join(roomCode: roomCode, tripService: LezgoApp.tripService) {
        case .failed(let message):
            throw SiriRefusal.saying(message)
        case .joined(let session):
            SiriHandoff.shared.Joined(session)
            return .result(dialog: IntentDialog(stringLiteral: String(localized: .siriJoinedRoom(roomCode))))
        }
    }

    /// Joins with the join dialog's own code (US-02), so the trip is saved and checked the same way.
    @MainActor
    static func Join(
        roomCode: String,
        tripService: any TripService,
        storage: (any ActiveTripStorage)? = nil,
        profileStorage: (any ProfileStorage)? = nil
    ) async -> Outcome {
        let joiner = JoinTripViewModel(
            roomCode: roomCode,
            tripService: tripService,
            storage: storage,
            profileStorage: profileStorage
        )
        guard await joiner.submitCode(), let session = joiner.joinedSession else {
            return .failed(joiner.errorMessage ?? String(localized: .siriJoinFailed))
        }
        return .joined(session)
    }
}

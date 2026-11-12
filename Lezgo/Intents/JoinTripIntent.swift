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
    /// Joins in the background, so Siri keeps the conversation and speaks a wrong code; then brings the app to the
    /// front for the Trip Room. Coming to the front first cut Siri off on a real phone, and nothing was joined.
    static let supportedModes: IntentModes = [.background, .foreground(.dynamic)]

    /// A text field, not a number pad: Shortcuts reads a number pad's entry as a number and drops a leading zero, so
    /// "066335" became "66335". The code is text, and `SpokenRoomCode` keeps only its digits.
    @Parameter(
        title: "Room Code",
        inputOptions: String.IntentInputOptions(keyboardType: .asciiCapable, autocorrect: false),
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
        SiriLog.Note("Join a trip: heard \(code)")
        guard let roomCode = SpokenRoomCode.Parse(code) else {
            SiriLog.Note("Join a trip: not a 6-digit code, asking again")
            throw $code.needsValueError(IntentDialog(stringLiteral: String(localized: .siriRoomCodeInvalid)))
        }
        guard SiriTripMap.HasTripOnThisPhone() == false else {
            SiriLog.Note("Join a trip: refused, a trip is already on this phone")
            throw SiriRefusal.alreadyInTrip
        }
        switch await Self.Join(roomCode: roomCode, tripService: LezgoApp.tripService) {
        case .failed(let message):
            SiriLog.Note("Join a trip: failed with \(message)")
            throw SiriRefusal.saying(message)
        case .joined(let session):
            SiriLog.Note("Join a trip: joined \(roomCode), handing over to Home")
            SiriHandoff.shared.Joined(session)
            await Self.OpenApp(from: self)
            return .result(dialog: IntentDialog(stringLiteral: String(localized: .siriJoinedRoom(roomCode))))
        }
    }

    /// Brings Lezgo to the front for the Trip Room or Set Route. Where iOS does not allow it (a locked phone, CarPlay),
    /// the work is done anyway and Home opens the trip the next time Lezgo opens.
    @MainActor
    static func OpenApp(from intent: some AppIntent) async {
        guard intent.systemContext.currentMode.canContinueInForeground else {
            SiriLog.Note("Siri: cannot open Lezgo now, Home takes over when it opens")
            return
        }
        do {
            try await intent.continueInForeground(nil, alwaysConfirm: false)
        } catch {
            SiriLog.Note("Siri: opening Lezgo failed: \(error.localizedDescription)")
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

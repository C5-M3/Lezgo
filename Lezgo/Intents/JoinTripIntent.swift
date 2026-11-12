//
//  JoinTripIntent.swift
//  Lezgo
//
//  Created by Nathan Sudiara on 12/11/26.
//

import AppIntents
import Foundation

/// "Join a trip in Lezgo" (US-08): asks for the room code and opens Lezgo with the join dialog filled in, through the
/// same link as an invite (US-02), handed to Home inside the app (`IncomingLinks`). The person still taps "Join", so a
/// misheard code never adds the car to a wrong trip.
struct JoinTripIntent: AppIntent {
    static let title: LocalizedStringResource = "Join a Trip"
    static let description = IntentDescription("Opens Lezgo with a room code filled in, ready to join.")
    /// The app comes to the front before `perform` runs, so the join dialog is there when Siri finishes.
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

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let roomCode = SpokenRoomCode.Parse(code), let link = Self.JoinLink(roomCode: roomCode) else {
            throw $code.needsValueError(IntentDialog(stringLiteral: String(localized: .siriRoomCodeInvalid)))
        }
        IncomingLinks.shared.Open(link)
        return .result(dialog: IntentDialog(stringLiteral: String(localized: .siriOpeningRoom(roomCode))))
    }

    /// `lezgo://join?code=897654`, which Home already turns into the filled-in join dialog (ADR 0020).
    static func JoinLink(roomCode: String) -> URL? {
        var components = URLComponents()
        components.scheme = "lezgo"
        components.host = "join"
        components.queryItems = [URLQueryItem(name: "code", value: roomCode)]
        return components.url
    }
}

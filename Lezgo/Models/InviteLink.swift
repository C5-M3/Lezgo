//
//  InviteLink.swift
//  Lezgo
//
//  Created by Oky Faishal on 30/10/26.
//

import Foundation

/// The invite link a group shares to join a trip (US-02, US-04).
///
/// It is a universal link on a static Netlify site (ADR 0020), because chat apps only let people tap `https://`
/// links. The older `lezgo://join?code=` link is still read, so invites sent before the change keep working.
enum InviteLink {
    static let host = "lezgo.netlify.app"
    static let path = "/join"

    /// For example `https://lezgo.netlify.app/join?code=897654`.
    static func Make(roomCode: String) -> URL? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = host
        components.path = path
        components.queryItems = [URLQueryItem(name: "code", value: roomCode)]
        return components.url
    }

    /// The room code in an invite link, or `nil` for any other link or a code that is not six plain digits.
    static func RoomCode(from url: URL) -> String? {
        guard IsInviteLink(url) else { return nil }
        let code = URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?
            .first { $0.name == "code" }?
            .value
        guard let code, Trip.IsValidRoomCode(code) else { return nil }
        return code
    }

    private static func IsInviteLink(_ url: URL) -> Bool {
        switch url.scheme?.lowercased() {
        case "https":
            let isJoinPath = url.path == path || url.path == path + "/"
            return url.host?.lowercased() == host && isJoinPath
        case "lezgo":
            return url.host?.lowercased() == "join"
        default:
            return false
        }
    }
}

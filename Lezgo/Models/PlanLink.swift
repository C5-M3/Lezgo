//
//  PlanLink.swift
//  Lezgo
//
//  Created by Nathan Sudiara on 12/11/26.
//

import Foundation

/// The link "Create a trip" from Siri opens (`specs/UserStories.md` → US-08): `lezgo://plan?to=Malang`. Home reads it
/// and opens Set Route searching for the place. Siri never picks the place itself.
enum PlanLink {
    /// A place longer than this is cut, so a misheard sentence never fills the search box with a paragraph.
    static let maxLength = 100

    /// `nil` for an empty place.
    static func Make(destination: String) -> URL? {
        guard let place = Clean(destination) else { return nil }
        var components = URLComponents()
        components.scheme = "lezgo"
        components.host = "plan"
        components.queryItems = [URLQueryItem(name: "to", value: place)]
        return components.url
    }

    /// The place in a plan link, or `nil` for any other link or an empty place.
    static func Destination(from url: URL) -> String? {
        guard url.scheme?.lowercased() == "lezgo", url.host?.lowercased() == "plan" else { return nil }
        let place = URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?
            .first { $0.name == "to" }?
            .value
        return place.flatMap(Clean)
    }

    private static func Clean(_ place: String) -> String? {
        let trimmed = place.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return nil }
        return String(trimmed.prefix(maxLength))
    }
}

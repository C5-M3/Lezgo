//
//  Font+Lezgo.swift
//  Lezgo
//

import SwiftUI

extension Font {
    /// The title of a page, between the Back button and the content (Trip History, Plan the route, Set Starting
    /// Point). One definition, so every page title has the same size.
    static let lezgoPageTitle = Font.title2.weight(.bold)

    /// The title of a section of a page (Overview, Participants). Semibold and a step above the headline values under
    /// it, so it does not read as one of them.
    static let lezgoSectionTitle = Font.title2.weight(.semibold)
}

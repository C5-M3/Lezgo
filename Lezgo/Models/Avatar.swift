//
//  Avatar.swift
//  Lezgo
//
//  Created by oky faishal on 05/11/26.
//

import Foundation
import SwiftUI

/// The mascot a car shows to the group (`specs/UserStories.md` → US-04, "Avatar").
///
/// Each avatar is a set of finished images told apart by asset name ("MainSelectedBlue", "OntripGlowBlue", …), so
/// the raw value is the part those names share. It is also the string stored in CloudKit and on the phone.
enum Avatar: String, Hashable, Codable, CaseIterable, Sendable {
    case yellow = "Yellow"
    case blue = "Blue"
    case green = "Green"
    case pink = "Pink"
    case purple = "Purple"

    /// Inisialisasi Avatar dari string case-insensitive (misal "yellow", "Yellow", "YELLOW").
    init?(caseInsensitive value: String?) {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            return nil
        }
        if let exact = Avatar(rawValue: value) {
            self = exact
            return
        }
        let lower = value.lowercased()
        if let match = Avatar.allCases.first(where: { $0.rawValue.lowercased() == lower }) {
            self = match
            return
        }
        return nil
    }

    /// Gambar depan avatar robot dengan wajah menyala.
    var frontImage: ImageResource {
        switch self {
        case .yellow: .frontballActiveYellow
        case .purple: .frontballActivePurple
        case .pink: .frontballActivePink
        case .blue: .frontballActiveBlue
        case .green: .frontballActiveGreen
        }
    }

    /// Tampilan atas robot sebagai pin mobil di peta.
    var topViewImage: ImageResource {
        switch self {
        case .yellow: .ontripNoglowYellow
        case .purple: .ontripNoglowPurple
        case .pink: .ontripNoglowPink
        case .blue: .ontripNoglowBlue
        case .green: .ontripNoglowGreen
        }
    }

    /// Tampilan avatar maskot utuh unselected dari Resource -> Assets -> MainUnselected.
    var unselectedImage: ImageResource {
        switch self {
        case .yellow: .mainUnselectedYellow
        case .purple: .mainUnselectedPurple
        case .pink: .mainUnselectedPink
        case .blue: .mainUnselectedBlue
        case .green: .mainUnselectedGreen
        }
    }

    /// What a member starts a trip with: every avatar but the leader's yellow.
    static let memberAvatars: [Avatar] = allCases.filter { $0 != .yellow }

    /// The avatar every trip starts with: yellow for the leader, a random other one for a member.
    static func Default(isLeader: Bool) -> Avatar {
        guard isLeader == false else { return .yellow }
        // memberAvatars is a fixed, non-empty list, so randomElement() never returns nil.
        return memberAvatars.randomElement() ?? .blue
    }
}

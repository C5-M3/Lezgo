//
//  AvatarImage.swift
//  Lezgo
//
//  Created by oky faishal on 05/11/26.
//

import SwiftUI

/// A car's mascot from the finished images in the asset catalog (`specs/UserStories.md` → US-04, "Avatar").
///
/// The selected image has a burst behind the mascot, so selected and unselected differ in shape, not only in colour.
/// It is decorative: the view that shows it says in words what it means.
struct AvatarImage: View {
    /// The size of an avatar in the Trip Room.
    static let roomSize: CGFloat = 160
    /// The size of the chosen avatar in Edit Profile.
    static let chosenSize: CGFloat = 270

    let avatar: Avatar
    /// The burst: ready at the start point in the participant list, or the chosen avatar in Edit Profile.
    let isSelected: Bool

    var body: some View {
        Image(resource)
            .resizable()
            .scaledToFit()
            .accessibilityHidden(true)
    }

    private var resource: ImageResource {
        switch (avatar, isSelected) {
        case (.yellow, true): .mainSelectedYellow
        case (.yellow, false): .mainUnselectedYellow
        case (.blue, true): .mainSelectedBlue
        case (.blue, false): .mainUnselectedBlue
        case (.green, true): .mainSelectedGreen
        case (.green, false): .mainUnselectedGreen
        case (.pink, true): .mainSelectedPink
        case (.pink, false): .mainUnselectedPink
        case (.purple, true): .mainSelectedPurple
        case (.purple, false): .mainUnselectedPurple
        }
    }
}

extension Avatar {
    /// What VoiceOver says for this avatar, for example "Blue avatar".
    var accessibilityName: String {
        switch self {
        case .yellow: String(localized: "Yellow avatar")
        case .blue: String(localized: "Blue avatar")
        case .green: String(localized: "Green avatar")
        case .pink: String(localized: "Pink avatar")
        case .purple: String(localized: "Purple avatar")
        }
    }
}

#if DEBUG
#Preview("Every avatar") {
    Grid {
        GridRow {
            ForEach(Avatar.allCases, id: \.self) { AvatarImage(avatar: $0, isSelected: true) }
        }
        GridRow {
            ForEach(Avatar.allCases, id: \.self) { AvatarImage(avatar: $0, isSelected: false) }
        }
    }
    .padding()
    .background(.black)
}
#endif

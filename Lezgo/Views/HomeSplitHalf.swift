//
//  HomeSplitHalf.swift
//  Lezgo
//
//  Created by Nathan Sudiara on 16/11/26.
//

import SwiftUI

/// One layer of the split-screen Home (issue #329): the logo and the LEAD and JOIN words, in yellow on the dark layer
/// or in dark on a yellow layer, plus the mascots that belong to that half. The layers sit on top of each other and
/// the yellow ones are cut to their half, so a word changes color exactly where the diagonal crosses it.
struct HomeSplitHalf: View {
    enum Look {
        case dark
        /// The LEAD half, with the lead mascot.
        case yellowLead
        /// The JOIN half, with the crew.
        case yellowJoin
    }

    let look: Look
    let flow: HomeSplitMotion.Flow
    let progress: Double
    let canvas: CGSize

    private var isYellow: Bool { look != .dark }
    private var ink: Color { isYellow ? Color(.tripCard) : Color(.brandYellow) }
    private var scale: Double { canvas.width / HomeSplitMotion.canvasWidth }

    var body: some View {
        ZStack(alignment: .topLeading) {
            (isYellow ? Color(.brandYellow) : Color(.tripCard))

            Image(.lezgoIcon)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .foregroundStyle(isYellow ? Color(.tripCard) : .white)
                .frame(height: 21 * scale)
                .offset(x: 22 * scale, y: 92 * canvas.height / HomeSplitMotion.canvasHeight)

            if look == .yellowLead {
                let slot = HomeSplitMotion.mascotSlot
                MascotImage(.homeLeadMascot, width: slot.width, height: slot.height)
                    .modifier(HomeSplitPlacement(element: .mascot, flow: flow, progress: progress, canvas: canvas))
            }

            if look == .yellowJoin {
                ForEach(Array(Self.crew.enumerated()), id: \.offset) { index, image in
                    let slot = HomeSplitMotion.crewSlots[index]
                    MascotImage(image, width: slot.width, height: slot.height)
                        .modifier(
                            HomeSplitPlacement(element: .crew(index), flow: flow, progress: progress, canvas: canvas)
                        )
                }
            }

            Word(.homeLeadWord, size: HomeSplitMotion.leadWordSize)
                .modifier(HomeSplitPlacement(element: .leadWord, flow: flow, progress: progress, canvas: canvas))

            Word(.homeJoinWord, size: HomeSplitMotion.joinWordSize)
                .modifier(HomeSplitPlacement(element: .joinWord, flow: flow, progress: progress, canvas: canvas))
        }
        .frame(width: canvas.width, height: canvas.height, alignment: .topLeading)
        // The two halves are buttons with their own labels; what is drawn here only decorates them.
        .accessibilityHidden(true)
    }

    /// From the back of the pile to the front, in the order of `HomeSplitMotion.crewSlots`.
    private static let crew: [ImageResource] = [
        .homeCrewGreen, .homeCrewPink, .homeCrewBlue, .homeCrewPurple, .homeCrewYellow
    ]

    private func Word(_ resource: ImageResource, size: (width: Double, height: Double)) -> some View {
        Image(resource)
            .renderingMode(.template)
            .resizable()
            .foregroundStyle(ink)
            .frame(width: size.width * scale, height: size.height * scale)
            .accessibilityHidden(true)
    }

    private func MascotImage(_ resource: ImageResource, width: Double, height: Double) -> some View {
        Image(resource)
            .resizable()
            .frame(width: width * scale, height: height * scale)
            .accessibilityHidden(true)
    }
}

#Preview("Lead half") {
    HomeSplitHalf(look: .yellowLead, flow: .lead, progress: 0, canvas: CGSize(width: 402, height: 874))
}

#Preview("Join half on the JOIN home") {
    HomeSplitHalf(
        look: .yellowJoin,
        flow: .join,
        progress: HomeSplitMotion.joinHome,
        canvas: CGSize(width: 402, height: 874)
    )
}

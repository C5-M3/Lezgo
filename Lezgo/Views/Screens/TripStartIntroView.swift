//
//  TripStartIntroView.swift
//  Lezgo
//
//  Created by Nathan Sudiara on 05/11/26.
//

import SwiftUI

/// The yellow "Lez Go!" screen that opens the map when a trip starts. `TripStartIntro` says what happens when; this
/// view only draws it. With Reduce Motion the logo just stands still until the map fades in.
struct TripStartIntroView: View {
    @State private var startDate = Date.now
    @State private var size = CGSize.zero
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if reduceMotion {
                Scene(frame: TripStartIntro.FrameAt(TripStartIntro.robotLeaves - 0.2), size: size)
            } else {
                TimelineView(.animation) { context in
                    Scene(frame: TripStartIntro.FrameAt(context.date.timeIntervalSince(startDate)), size: size)
                }
            }
        }
        .onGeometryChange(for: CGSize.self, of: \.size) { size = $0 }
        .contentShape(.rect)
        // The animation says nothing the map does not say a moment later.
        .accessibilityHidden(true)
    }
}

extension TripStartIntroView {
    /// One frame of the animation, laid out for the screen size.
    struct Scene: View {
        let frame: TripStartIntro.Frame
        let size: CGSize

        /// The logo in Sketch, in points. The letters are placed relative to its top left corner.
        private static let logoSize = CGSize(width: 331.67, height: 313.5)
        private static let holeCenter = CGPoint(x: 200.33, y: 239.25)
        /// The robot's body fills this share of its image; the rest is transparent margin.
        private static let robotBodyShare = 0.426
        private static let robotBodyWidth = 133.0

        /// Fits the logo in a phone of any size, and in landscape.
        private var scale: Double {
            guard size.width > 0, size.height > 0 else { return 1 }
            return min(size.width / 402, size.height / 640)
        }

        /// Where the hole of the O is on screen.
        private var holeOnScreen: CGPoint {
            CGPoint(
                x: size.width / 2 + (Self.holeCenter.x - Self.logoSize.width / 2) * scale,
                y: size.height / 2 + (Self.holeCenter.y - Self.logoSize.height / 2) * scale
            )
        }

        /// How much further than Sketch's phone the zoom must go for the hole to pass every corner of this screen.
        private var zoomCoverage: Double {
            let farthestX = max(holeOnScreen.x, size.width - holeOnScreen.x)
            let farthestY = max(holeOnScreen.y, size.height - holeOnScreen.y)
            let needed = (farthestX * farthestX + farthestY * farthestY).squareRoot()
            let reached = TripStartIntro.holeRadius * TripStartIntro.finalZoom * scale
            return max(1, needed / reached)
        }

        private var zoom: Double {
            frame.logoZoom > 1 ? 1 + (frame.logoZoom - 1) * zoomCoverage : frame.logoZoom
        }

        private var holeRadius: Double {
            frame.holeRadius > 0 ? TripStartIntro.holeRadius * zoom * scale : 0
        }

        var body: some View {
            ZStack {
                ZStack {
                    Color(.brandYellow)
                    Logo(frame: frame, scale: scale)
                        .frame(width: Self.logoSize.width * scale, height: Self.logoSize.height * scale)
                        .scaleEffect(
                            zoom,
                            anchor: UnitPoint(
                                x: Self.holeCenter.x / Self.logoSize.width,
                                y: Self.holeCenter.y / Self.logoSize.height
                            )
                        )
                        .offset(y: frame.shakeOffsetY * scale)
                }
                .mask {
                    Rectangle()
                        .overlay {
                            Circle()
                                .frame(width: holeRadius * 2, height: holeRadius * 2)
                                .position(holeOnScreen)
                                .blendMode(.destinationOut)
                        }
                        .compositingGroup()
                }

                Image(.frontballActiveYellow)
                    .resizable()
                    .accessibilityHidden(true)
                    .frame(
                        width: Self.robotBodyWidth / Self.robotBodyShare * scale,
                        height: Self.robotBodyWidth / Self.robotBodyShare * scale
                    )
                    .scaleEffect(x: frame.robotScaleX, y: frame.robotScaleY)
                    .rotationEffect(.degrees(frame.robotRotationDegrees))
                    .position(holeOnScreen)
                    // On a wide screen the robot must travel further to start and end out of sight.
                    .offset(
                        x: frame.robotOffsetX * max(scale, size.width / 402),
                        y: frame.shakeOffsetY * scale
                    )
            }
        }
    }

    /// The letters, each growing from its own baseline.
    struct Logo: View {
        let frame: TripStartIntro.Frame
        let scale: Double

        var body: some View {
            ZStack(alignment: .topLeading) {
                Letter(image: .logoLetterL, x: 0, y: 0, width: 102.67, growth: Growth(.letterL), scale: scale)
                Letter(image: .logoLetterE, x: 109.83, y: 0, width: 93.33, growth: Growth(.letterE), scale: scale)
                Letter(image: .logoLetterZ, x: 210.5, y: 0, width: 120.67, growth: Growth(.letterZ), scale: scale)
                Letter(image: .logoLetterG, x: 0, y: 165, width: 118.67, growth: Growth(.letterG), scale: scale)
                Letter(image: .logoLetterO, x: 126, y: 165, width: 148.67, growth: Growth(.letterO), scale: scale)
                Letter(image: .logoLetterBang, x: 289.33, y: 165, width: 42.33, growth: Growth(.bang), scale: scale)
                    .rotationEffect(
                        .degrees(frame.bangTiltDegrees),
                        anchor: UnitPoint(x: (289.33 + 21) / 331.67, y: 1)
                    )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }

        private func Growth(_ letter: TripStartIntro.Letter) -> Double {
            frame.Growth(of: letter)
        }
    }

    /// One letter of the logo at its place in the Sketch layout.
    struct Letter: View {
        let image: ImageResource
        let x: Double
        let y: Double
        let width: Double
        let growth: Double
        let scale: Double

        private static let height = 148.5

        var body: some View {
            Image(image)
                .resizable()
                .accessibilityHidden(true)
                .frame(width: width * scale, height: Self.height * scale)
                .scaleEffect(x: 1, y: growth, anchor: .bottom)
                .offset(x: x * scale, y: y * scale)
        }
    }
}

#Preview("Plays once") {
    TripStartIntroView()
        .ignoresSafeArea()
}

#Preview("Logo complete, the way Reduce Motion shows it") {
    GeometryReader { proxy in
        TripStartIntroView.Scene(frame: TripStartIntro.FrameAt(TripStartIntro.robotLeaves - 0.2), size: proxy.size)
    }
    .ignoresSafeArea()
}

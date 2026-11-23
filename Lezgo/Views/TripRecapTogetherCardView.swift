//
//  TripRecapTogetherCardView.swift
//  Lezgo
//

import SwiftUI

/// The Together card: "We drove 60 km together." with the distance in huge yellow letters, the route line drawn
/// across the number, the cars, stops and time, the route in words and the robots of everyone who drove.
/// The canvas is 9:16 and transparent, like the other cards.
///
/// This is a picture, not a screen: sizes are fixed on purpose, so the picture looks the same on every phone.
struct TripRecapTogetherCardView: View {
    let content: TripRecapShareCardContent
    let mapPicture: TripRecapMapPicture

    /// A thin dark edge on the route line, so it stays readable over the yellow number.
    private let routeEdge = Color(white: 0.07)
    private let numberHeight = 200.0

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center) {
                TripRecapShareLogo(image: .lezgoYellow)
                Spacer()
                Text(content.numericDateText)
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.55))
            }

            Text(content.togetherLeadText)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white.opacity(0.55))
                .padding(.top, 52)

            number
                .padding(.top, 20)

            Text(content.togetherClosingText)
                .font(.system(size: 56, weight: .heavy))
                .foregroundStyle(.white)
                .padding(.top, 22)

            Text("\(content.carsText). \(content.stopsText). \(content.timeText).")
                .font(.system(size: 18))
                .foregroundStyle(.white.opacity(0.55))
                .padding(.top, 2)

            Text(content.routeText)
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.5))
                .lineLimit(2)
                .padding(.top, 6)

            robots
                .padding(.top, 36)

            Spacer(minLength: 0)
        }
        .shareTextShadow()
        .padding(.horizontal, 24)
        .padding(.top, 34)
        .frame(width: TripRecapShareCardView.canvasSize.width, height: TripRecapShareCardView.canvasSize.height)
        .environment(\.dynamicTypeSize, .large)
        .environment(\.colorScheme, .dark)
    }

    /// The distance number, the route over it, and the unit under its right edge.
    private var number: some View {
        Text(content.distanceNumberText)
            .font(.system(size: 250, weight: .black))
            .foregroundStyle(Color(.brandYellow))
            .lineLimit(1)
            .minimumScaleFactor(0.25)
            .frame(maxWidth: .infinity, minHeight: numberHeight, maxHeight: numberHeight)
            .overlay {
                TripRecapShareRoute(
                    points: mapPicture.routePoints, lineWidth: 2.5, lineColor: .white, outlineColor: routeEdge
                )
                .padding(.horizontal, -6)
                .padding(.vertical, 12)
            }
            .overlay(alignment: .bottomTrailing) {
                Text(content.distanceUnitText)
                    .font(.system(size: 62, weight: .black))
                    .foregroundStyle(.white)
                    .offset(x: -14, y: 34)
            }
    }

    private var robots: some View {
        HStack(spacing: -10) {
            ForEach(content.robots.indices, id: \.self) { index in
                Image(content.robots[index].unselectedImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 72, height: 72)
            }
            if content.hiddenRobotCount > 0 {
                Text("+\(content.hiddenRobotCount)")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white.opacity(0.7))
                    .padding(.leading, 10)
            }
        }
        .accessibilityHidden(true)
    }
}

#if DEBUG
#Preview {
    TripRecapTogetherCardView(
        content: TripRecapShareCardContent(recap: .sample),
        mapPicture: TripRecapMapPicture(
            image: UIImage(),
            routePoints: [
                CGPoint(x: 6, y: 80), CGPoint(x: 30, y: 84), CGPoint(x: 44, y: 98), CGPoint(x: 60, y: 70),
                CGPoint(x: 84, y: 76), CGPoint(x: 100, y: 52), CGPoint(x: 128, y: 24)
            ],
            startPoint: CGPoint(x: 6, y: 80),
            destinationPoint: CGPoint(x: 128, y: 24)
        )
    )
}
#endif

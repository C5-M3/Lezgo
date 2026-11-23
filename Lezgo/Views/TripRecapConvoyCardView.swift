//
//  TripRecapConvoyCardView.swift
//  Lezgo
//

import SwiftUI

/// The Convoy card: the route as one big white line, with the route in words and Distance, Elapsed and Stops in a
/// row at the bottom. The canvas is 9:16 and transparent, like the other cards.
///
/// This is a picture, not a screen: sizes are fixed on purpose, so the picture looks the same on every phone.
struct TripRecapConvoyCardView: View {
    let content: TripRecapShareCardContent
    let mapPicture: TripRecapMapPicture

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            TripRecapShareLogo(image: .lezgoYellow)

            TripRecapShareRoute(points: mapPicture.routePoints, lineWidth: 4, showsDestinationRing: true)
                .frame(height: 300)
                .padding(.top, 80)

            Spacer(minLength: 0)

            Text(content.routeText)
                .font(.system(size: 15))
                .foregroundStyle(.white.opacity(0.6))
                .lineLimit(2)

            Text(content.convoyTitleText)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(.white)
                .padding(.top, 4)

            HStack(alignment: .top, spacing: 0) {
                stat("Distance", "\(content.distanceNumberText) \(content.distanceUnitText)", width: 130)
                stat("Elapsed", content.timeText, width: 120)
                stat("Stops", content.stopsNumberText, width: nil)
            }
            .padding(.top, 14)
        }
        .shareTextShadow()
        .padding(.horizontal, 24)
        .padding(.top, 34)
        .padding(.bottom, 34)
        .frame(width: TripRecapShareCardView.canvasSize.width, height: TripRecapShareCardView.canvasSize.height)
        .environment(\.dynamicTypeSize, .large)
        .environment(\.colorScheme, .dark)
    }

    private func stat(_ title: LocalizedStringKey, _ value: String, width: CGFloat?) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.system(size: 15))
                .foregroundStyle(.white.opacity(0.6))
            Text(value)
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(width: width, alignment: .leading)
    }
}

#if DEBUG
#Preview {
    TripRecapConvoyCardView(
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

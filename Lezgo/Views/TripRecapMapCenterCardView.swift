//
//  TripRecapMapCenterCardView.swift
//  Lezgo
//

import SwiftUI

/// The Map Center trip recap card: the map in the middle, the logo, From and Time on its left, and the date, To and
/// Distance on its right. The canvas is 9:16 and transparent, like the other cards, and the card sits above the area
/// an Instagram Story covers with its own buttons.
///
/// This is a picture, not a screen: sizes are fixed on purpose, so the picture looks the same on every phone.
struct TripRecapMapCenterCardView: View {
    let content: TripRecapShareCardContent
    let mapPicture: TripRecapMapPicture

    private let mapSide = 104.0
    private let columnWidth = 98.0
    /// The top row holds the logo or a date that may take two lines, so both columns line up underneath it.
    private let topRowHeight = 36.0
    /// Two lines of a value and its title, so a long name does not push the rows below it out of line.
    private let detailHeight = 50.0

    var body: some View {
        HStack(alignment: .center, spacing: 6) {
            VStack(alignment: .leading, spacing: 12) {
                TripRecapShareLogo()
                    .frame(height: topRowHeight, alignment: .topLeading)
                detail("From", content.fromText, alignment: .leading)
                detail("Time", content.timeText, alignment: .leading)
            }

            TripRecapShareMap(mapPicture: mapPicture, leaderAvatar: content.leaderAvatar)
                .scaleEffect(mapSide / TripRecapMapPicture.side)
                .frame(width: mapSide, height: mapSide)

            VStack(alignment: .trailing, spacing: 12) {
                Text(content.dateText)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                    .multilineTextAlignment(.trailing)
                    .shareTextShadow()
                    .frame(width: columnWidth, height: topRowHeight, alignment: .topTrailing)
                detail("To", content.toText, alignment: .trailing)
                detail("Distance", content.distanceText, alignment: .trailing)
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 110)
        .frame(
            width: TripRecapShareCardView.canvasSize.width,
            height: TripRecapShareCardView.canvasSize.height,
            alignment: .bottom
        )
        .environment(\.dynamicTypeSize, .large)
        .environment(\.colorScheme, .dark)
    }

    private func detail(_ title: LocalizedStringKey, _ value: String, alignment: HorizontalAlignment) -> some View {
        TripRecapShareDetail(title: title, value: value, width: columnWidth, alignment: alignment)
            .frame(height: detailHeight, alignment: .top)
    }
}

#if DEBUG
#Preview {
    TripRecapMapCenterCardView(
        content: TripRecapShareCardContent(recap: .sample),
        mapPicture: TripRecapMapPicture(
            image: UIImage(systemName: "map") ?? UIImage(),
            routePoints: [CGPoint(x: 20, y: 110), CGPoint(x: 70, y: 70), CGPoint(x: 120, y: 30)],
            startPoint: CGPoint(x: 20, y: 110),
            destinationPoint: CGPoint(x: 120, y: 30)
        )
    )
    .background(.gray)
}
#endif

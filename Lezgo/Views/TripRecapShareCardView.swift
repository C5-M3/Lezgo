//
//  TripRecapShareCardView.swift
//  Lezgo
//

import SwiftUI

/// The trip recap card that is turned into the shared picture. The canvas is 9:16 and transparent; the card sits in
/// the bottom-left, above the area an Instagram Story covers with its own buttons.
///
/// This is a picture, not a screen: sizes are fixed on purpose, so the picture looks the same on every phone.
struct TripRecapShareCardView: View {
    let content: TripRecapShareCardContent
    let mapPicture: TripRecapMapPicture

    /// The canvas in points; drawn at 3x it is 1080 x 1920 pixels.
    static let canvasSize = CGSize(width: 360, height: 640)

    private let columnWidth = 118.0

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            TripRecapShareLogo()

            Text(content.dateText)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white)
                .shareTextShadow()

            TripRecapShareMap(mapPicture: mapPicture, leaderAvatar: content.leaderAvatar)

            Grid(alignment: .topLeading, horizontalSpacing: 20, verticalSpacing: 12) {
                GridRow {
                    TripRecapShareDetail(title: "From", value: content.fromText, width: columnWidth)
                    TripRecapShareDetail(title: "To", value: content.toText, width: columnWidth)
                }
                GridRow {
                    TripRecapShareDetail(title: "Time", value: content.timeText, width: columnWidth)
                    TripRecapShareDetail(title: "Distance", value: content.distanceText, width: columnWidth)
                }
            }
            .frame(width: columnWidth * 2 + 20, alignment: .leading)
        }
        .padding(.leading, 28)
        .padding(.bottom, 110)
        .frame(width: Self.canvasSize.width, height: Self.canvasSize.height, alignment: .bottomLeading)
        .environment(\.dynamicTypeSize, .large)
        .environment(\.colorScheme, .dark)
    }
}

#if DEBUG
#Preview {
    TripRecapShareCardView(
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

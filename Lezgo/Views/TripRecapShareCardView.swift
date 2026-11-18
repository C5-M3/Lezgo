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
            Image(.lezgoWhite)
                .resizable()
                .scaledToFit()
                .frame(width: 76, height: 40)
                // The logo file has empty space above and below the letters; cut it away.
                .frame(height: 20)
                .clipped()
                .shareTextShadow()
                .accessibilityHidden(true)

            Text(content.dateText)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white)
                .shareTextShadow()

            mapView

            Grid(alignment: .topLeading, horizontalSpacing: 20, verticalSpacing: 12) {
                GridRow {
                    Detail(title: "From", value: content.fromText)
                    Detail(title: "To", value: content.toText)
                }
                GridRow {
                    Detail(title: "Time", value: content.timeText)
                    Detail(title: "Distance", value: content.distanceText)
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

    private var mapView: some View {
        ZStack {
            Image(uiImage: mapPicture.image)
                .resizable()
                .accessibilityHidden(true)

            Path { path in
                path.addLines(mapPicture.routePoints)
            }
            .stroke(Color(.tripCard), style: RouteLineMapContent.Stroke(width: 6))

            Path { path in
                path.addLines(mapPicture.routePoints)
            }
            .stroke(Color(.brandYellow), style: RouteLineMapContent.Stroke(width: 3))

            RouteStopPin(kind: .destination)
                .scaleEffect(0.5)
                .position(mapPicture.destinationPoint)

            Image(content.leaderAvatar.topViewImage)
                .resizable()
                .scaledToFit()
                .frame(width: 24, height: 24)
                .position(mapPicture.startPoint)
                .accessibilityHidden(true)
        }
        .frame(width: TripRecapMapPicture.side, height: TripRecapMapPicture.side)
        .clipShape(.rect(cornerRadius: 6))
    }

    private struct Detail: View {
        let title: LocalizedStringKey
        let value: String

        var body: some View {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.6))
                Text(value)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
            }
            .frame(width: 118, alignment: .leading)
            .shareTextShadow()
        }
    }
}

private extension View {
    /// A very light dark shadow, so white text stays readable on a light background without showing on a dark one.
    func shareTextShadow() -> some View {
        shadow(color: .black.opacity(0.3), radius: 1.5, x: 0, y: 0.5)
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

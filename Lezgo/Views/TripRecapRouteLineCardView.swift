//
//  TripRecapRouteLineCardView.swift
//  Lezgo
//

import SwiftUI

/// The Route Line trip recap card: no map, only the route line. Logo and date at the top, From and To under them,
/// and Time, the route line and Distance in one row near the bottom. The canvas is 9:16 and transparent, like the
/// classic card, and the bottom is left free for the area an Instagram Story covers with its own buttons.
///
/// This is a picture, not a screen: sizes are fixed on purpose, so the picture looks the same on every phone.
struct TripRecapRouteLineCardView: View {
    let content: TripRecapShareCardContent
    let mapPicture: TripRecapMapPicture

    /// Tall on purpose: a route that goes north to south would be a tiny line in a short row.
    private let routeHeight = 150.0
    /// Room around the line so the start robot and the destination pin are not cut off at the edges.
    private let routeMargin = 14.0

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center) {
                TripRecapShareLogo()
                Spacer()
                Text(content.dateText)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                    .shareTextShadow()
            }

            HStack(alignment: .top, spacing: 20) {
                TripRecapShareDetail(title: "From", value: content.fromText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                TripRecapShareDetail(title: "To", value: content.toText, alignment: .trailing)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }

            Spacer(minLength: 0)

            HStack(alignment: .bottom, spacing: 8) {
                TripRecapShareDetail(title: "Time", value: content.timeText)
                    .fixedSize()
                routeLine
                TripRecapShareDetail(title: "Distance", value: content.distanceText, alignment: .trailing)
                    .fixedSize()
            }
        }
        .padding(.horizontal, 28)
        .padding(.top, 78)
        .padding(.bottom, 110)
        .frame(width: TripRecapShareCardView.canvasSize.width, height: TripRecapShareCardView.canvasSize.height)
        .environment(\.dynamicTypeSize, .large)
        .environment(\.colorScheme, .dark)
    }

    private var routeLine: some View {
        Canvas { context, size in
            let area = CGSize(width: size.width - routeMargin * 2, height: size.height - routeMargin * 2)
            let points = TripRecapShareRoute.FittedPoints(mapPicture.routePoints, in: area)
                .map { CGPoint(x: $0.x + routeMargin, y: $0.y + routeMargin) }

            var path = Path()
            path.addLines(points)
            let round = { (width: CGFloat) in StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round) }
            context.stroke(path, with: .color(Color(.tripCard)), style: round(6))
            context.stroke(path, with: .color(Color(.brandYellow)), style: round(3))

            if let end = points.last, let pin = context.resolveSymbol(id: "destination") {
                context.draw(pin, at: end)
            }
            if let start = points.first, let leader = context.resolveSymbol(id: "leader") {
                context.draw(leader, at: start)
            }
        } symbols: {
            RouteStopPin(kind: .destination)
                .scaleEffect(0.5)
                .tag("destination")
            Image(content.leaderAvatar.topViewImage)
                .resizable()
                .scaledToFit()
                .frame(width: 24, height: 24)
                .tag("leader")
        }
        .frame(height: routeHeight)
        .accessibilityHidden(true)
    }
}

#if DEBUG
#Preview {
    TripRecapRouteLineCardView(
        content: TripRecapShareCardContent(recap: .sample),
        mapPicture: TripRecapMapPicture(
            image: UIImage(systemName: "map") ?? UIImage(),
            routePoints: [
                CGPoint(x: 6, y: 80), CGPoint(x: 30, y: 84), CGPoint(x: 44, y: 98), CGPoint(x: 60, y: 70),
                CGPoint(x: 84, y: 76), CGPoint(x: 100, y: 52), CGPoint(x: 128, y: 24)
            ],
            startPoint: CGPoint(x: 6, y: 80),
            destinationPoint: CGPoint(x: 128, y: 24)
        )
    )
    .background(.gray)
}
#endif

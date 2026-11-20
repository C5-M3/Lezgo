//
//  TripRecapShareCardParts.swift
//  Lezgo
//

import SwiftUI

/// A small grey title over a bold value ("From" over "Universitas Ciputra") on a trip recap picture. This is part of
/// a picture, not a screen: sizes are fixed on purpose.
struct TripRecapShareDetail: View {
    let title: LocalizedStringKey
    let value: String
    /// Fixed width, or `nil` to take the room the parent gives.
    var width: CGFloat?
    var alignment: HorizontalAlignment = .leading

    var body: some View {
        VStack(alignment: alignment, spacing: 2) {
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.6))
            Text(value)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white)
                .lineLimit(2)
                .multilineTextAlignment(alignment == .trailing ? .trailing : .leading)
        }
        .frame(width: width, alignment: alignment == .trailing ? .trailing : .leading)
        .shareTextShadow()
    }
}

/// The Lezgo logo, cut to the height of its letters, at the top of a trip recap picture. White over a photo, yellow
/// on the dark posters.
struct TripRecapShareLogo: View {
    var image: ImageResource = .lezgoWhite

    var body: some View {
        Image(image)
            .resizable()
            .scaledToFit()
            .frame(width: 76, height: 40)
            // The logo file has empty space above and below the letters; cut it away.
            .frame(height: 20)
            .clipped()
            .shareTextShadow()
            .accessibilityHidden(true)
    }
}

/// The still map of the trip with the route, the leader's robot at the start and the pin at the destination, as it
/// appears on a trip recap picture. It is `TripRecapMapPicture.side` points square.
struct TripRecapShareMap: View {
    let mapPicture: TripRecapMapPicture
    let leaderAvatar: Avatar

    var body: some View {
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

            Image(leaderAvatar.topViewImage)
                .resizable()
                .scaledToFit()
                .frame(width: 24, height: 24)
                .position(mapPicture.startPoint)
                .accessibilityHidden(true)
        }
        .frame(width: TripRecapMapPicture.side, height: TripRecapMapPicture.side)
        .clipShape(.rect(cornerRadius: 6))
    }
}

extension View {
    /// A very light dark shadow, so white text stays readable on a light background without showing on a dark one.
    func shareTextShadow() -> some View {
        shadow(color: .black.opacity(0.3), radius: 1.5, x: 0, y: 0.5)
    }
}

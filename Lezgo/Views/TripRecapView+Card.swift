//
//  TripRecapView+Card.swift
//  Lezgo
//
//  Created by Rizal Pratama on 17/11/26.
//

import MapKit
import SwiftUI

// MARK: - Trip Recap Card

struct TripRecapCard: View {
    let item: TripRecap

    /// The avatar asset has transparent margins: ~29.4% horizontal (603/2048 px)
    /// and ~28.6% vertical (585/2048 px).
    /// Negative padding aligns the visible robot avatar leading edge with the text above.
    private static let avatarLeadingOffset: CGFloat = 50 * (603.0 / 2048.0)
    private static let avatarVerticalOffset: CGFloat = 50 * (585.0 / 2048.0)

    /// Menghasilkan avatar yang dinamis mengikuti data dari `item.dynamicAvatars`.
    private var displayedAvatars: [Avatar] {
        Array(item.dynamicAvatars.prefix(4))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            mapSection
            infoSection
        }
        .background(Color(red: 28/255, green: 28/255, blue: 30/255))
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    @ViewBuilder
    private var mapSection: some View {
        Map(initialPosition: .rect(item.boundingRect), interactionModes: []) {
            RouteLineMapContent(coordinates: item.polyline.map(\.locationCoordinate))

            if let start = item.polyline.first {
                Annotation("", coordinate: start.locationCoordinate) {
                    Image(displayedAvatars.first?.topViewImage ?? .ontripNoglowYellow)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 40, height: 40)
                        .accessibilityHidden(true)
                }
            }

            if let destination = item.polyline.last {
                Annotation("", coordinate: destination.locationCoordinate) {
                    VStack(spacing: 2) {
                        RouteStopPin(kind: .destination)
                            .scaleEffect(0.75)

                        Text(item.destinationLabel)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.85), radius: 3, x: 0, y: 1)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 130)
                    }
                }
            }
        }
        .mapStyle(.lezgo)
        .preferredColorScheme(.dark)
        .frame(height: 180)
        .disabled(true)
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.destinationName)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)

                Text(item.formattedDate)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color(white: 0.4))
            }

            HStack(spacing: 0) {
                if !displayedAvatars.isEmpty {
                    HStack(spacing: -22) {
                        ForEach(Array(displayedAvatars.enumerated()), id: \.offset) { index, avatar in
                            Image(avatar.frontImage)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 50, height: 50)
                                .accessibilityHidden(true)
                                .zIndex(Double(displayedAvatars.count - index))
                        }
                    }
                    .padding(.leading, -Self.avatarLeadingOffset)
                    .padding(.vertical, -Self.avatarVerticalOffset)
                }

                Text("\(item.participantCount) people · \(item.distanceText)")
                    .font(.subheadline)
                    .foregroundStyle(Color(white: 0.6))
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Skeleton & Shimmer

struct TripRecapCardSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Map placeholder
            Rectangle()
                .fill(Color(white: 0.16))
                .frame(height: 180)

            // Info placeholder
            VStack(alignment: .leading, spacing: 12) {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color(white: 0.22))
                    .frame(width: 180, height: 20)

                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(Color(white: 0.18))
                    .frame(width: 120, height: 14)

                HStack(spacing: 8) {
                    HStack(spacing: -10) {
                        ForEach(0..<3, id: \.self) { _ in
                            Circle()
                                .fill(Color(white: 0.24))
                                .frame(width: 30, height: 30)
                        }
                    }

                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(Color(white: 0.18))
                        .frame(width: 130, height: 14)
                }
                .padding(.top, 4)
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color(red: 28/255, green: 28/255, blue: 30/255))
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
    }
}

struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = -1.0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        if reduceMotion {
            content
        } else {
            content
                .overlay {
                    GeometryReader { proxy in
                        let width = proxy.size.width
                        LinearGradient(
                            stops: [
                                .init(color: .clear, location: 0.0),
                                .init(color: Color.white.opacity(0.15), location: 0.5),
                                .init(color: .clear, location: 1.0)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: width * 1.5)
                        .offset(x: phase * width * 1.5)
                    }
                    .mask(content)
                    .allowsHitTesting(false)
                }
                .onAppear {
                    withAnimation(
                        .linear(duration: 1.5)
                        .repeatForever(autoreverses: false)
                    ) {
                        phase = 1.0
                    }
                }
        }
    }
}

extension View {
    func shimmer() -> some View {
        modifier(ShimmerModifier())
    }
}

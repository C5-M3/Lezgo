//
//  TripMapOnTheGoTrack.swift
//  Lezgo
//
//  Created by Oky Faishal on 18/11/26.
//

import SwiftUI

/// The line on the On the Go card from the start to the flag, with a robot head for each car where it is on the
/// route. The line is yellow up to the car in front and grey after it (ADR 0034).
struct TripMapOnTheGoTrack: View {
    let progress: TripMapViewModel.RouteProgress?

    @State private var width = 0.0

    private static let headSize = 40.0
    /// The width of the flag, where the end of the track is.
    private static let flagSize = 24.0
    private static let ringSize = 15.0
    private static let lineThickness = 4.0

    var body: some View {
        VStack(spacing: 4) {
            ZStack(alignment: .leading) {
                Line()
                Ring()
                ForEach(progress?.cars ?? []) { car in
                    Image(car.carColor.frontImage)
                        .resizable()
                        .scaledToFit()
                        .frame(width: Self.headSize, height: Self.headSize)
                        .offset(x: Offset(of: car.fraction))
                }
                Image(systemName: "flag.checkered")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(Color(.brandYellow))
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .frame(height: Self.headSize)
            .onGeometryChange(for: Double.self, of: { Double($0.size.width) }, action: { width = $0 })

            HStack {
                Text(.tripMapOnTheGoStart)
                Spacer()
                Text(.tripMapOnTheGoEnd)
            }
            .font(.system(size: 9))
            .foregroundStyle(Color(.tripCardSubtext))
        }
        // The track is a picture of the route; the cars are named in the list below.
        .accessibilityHidden(true)
    }

    /// How far a car can go along the track: from the ring's centre to the flag's centre.
    private var travel: Double {
        max(width - Self.ringSize / 2 - Self.flagSize / 2, 0)
    }

    /// Where the head's left edge goes, so that its centre is on the car's place on the track.
    private func Offset(of fraction: Double) -> Double {
        Self.ringSize / 2 + travel * fraction - Self.headSize / 2
    }

    private func Line() -> some View {
        ZStack(alignment: .leading) {
            Capsule()
                .fill(Color(.surfaceSeparator))
                .frame(height: Self.lineThickness)
            Capsule()
                .fill(Color(.brandYellow))
                .frame(width: Self.ringSize / 2 + travel * (progress?.leadFraction ?? 0), height: Self.lineThickness)
        }
    }

    private func Ring() -> some View {
        Circle()
            .strokeBorder(Color(.brandYellow), lineWidth: 3)
            .background(Color(.tripCardButton), in: .circle)
            .frame(width: Self.ringSize, height: Self.ringSize)
    }
}

#Preview("Cars on the way") {
    TripMapOnTheGoTrack(progress: .init(
        cars: [
            .init(id: UUID(), carColor: .green, fraction: 0.08),
            .init(id: UUID(), carColor: .blue, fraction: 0.35),
            .init(id: UUID(), carColor: .purple, fraction: 0.45),
            .init(id: UUID(), carColor: .pink, fraction: 0.65),
            .init(id: UUID(), carColor: .yellow, fraction: 0.74)
        ],
        leadFraction: 0.74
    ))
    .padding()
    .background(Color(.tripCardButton))
    .environment(\.colorScheme, .dark)
}

#Preview("No positions yet") {
    TripMapOnTheGoTrack(progress: nil)
        .padding()
        .background(Color(.tripCardButton))
        .environment(\.colorScheme, .dark)
}

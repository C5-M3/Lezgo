//
//  RouteMetricsBottomCard.swift
//  Lezgo
//
//  Created by Farrell Sudjatmiko on 05/11/26.
//

import CoreLocation
import SwiftUI

struct RouteMetricsBottomCard: View {
    let duration: TimeInterval
    let distance: CLLocationDistance
    let destinationCount: Int
    let hasIntermediateStops: Bool
    let isLoadingRoute: Bool
    let canSave: Bool
    let isSaving: Bool
    var saveTitle: LocalizedStringResource = "Save"
    let onSave: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            metricsHeaderRow
            saveButton
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(red: 26 / 255, green: 26 / 255, blue: 28 / 255))
        )
        .shadow(color: .black.opacity(0.3), radius: 14, x: 0, y: 6)
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    private var metricsHeaderRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            if isLoadingRoute {
                Text("Calculating…")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Color.heroYellow)
                    .lineLimit(1)
            } else {
                Text(FormattedDuration(duration))
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(Color.heroYellow)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }

            Spacer(minLength: 8)

            if !isLoadingRoute {
                Text(formattedSummaryText)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color(white: 0.65))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
        }
    }

    private var saveButton: some View {
        Button(action: onSave) {
            HStack {
                Spacer()
                if isSaving {
                    ProgressView()
                        .tint(.black)
                } else {
                    Text(saveTitle)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.black)
                }
                Spacer()
            }
            .frame(height: 52)
            .background(
                Capsule()
                    .fill(Color.heroYellow)
            )
        }
        .disabled(!canSave || isSaving)
        .opacity((canSave && !isSaving) ? 1.0 : 0.45)
        .accessibilityLabel(Text(saveTitle))
    }

    private var formattedSummaryText: String {
        let distanceText = FormattedDistance(distance)
        if hasIntermediateStops && destinationCount > 1 {
            return "\(distanceText) · \(destinationCount) Destinations"
        } else {
            return distanceText
        }
    }

    private func FormattedDuration(_ time: TimeInterval) -> String {
        let hours = Int(time) / 3600
        let minutes = (Int(time) % 3600) / 60

        if hours > 0 {
            if minutes > 0 {
                return "\(hours) h \(minutes) min"
            } else {
                return "\(hours) h"
            }
        } else {
            return "\(max(1, minutes)) min"
        }
    }

    private func FormattedDistance(_ meters: CLLocationDistance) -> String {
        if meters < 1000 {
            return "\(Int(meters)) m"
        } else {
            let kilometers = Int(round(meters / 1000.0))
            return "\(kilometers) km"
        }
    }
}

#Preview("2 Points") {
    ZStack {
        Color.black.ignoresSafeArea()
        VStack {
            Spacer()
            RouteMetricsBottomCard(
                duration: 37 * 60,
                distance: 18000,
                destinationCount: 2,
                hasIntermediateStops: false,
                isLoadingRoute: false,
                canSave: true,
                isSaving: false,
                onSave: {}
            )
        }
    }
}

#Preview("Multiple Stops") {
    ZStack {
        Color.black.ignoresSafeArea()
        VStack {
            Spacer()
            RouteMetricsBottomCard(
                duration: (2 * 3600) + (10 * 60),
                distance: 44000,
                destinationCount: 8,
                hasIntermediateStops: true,
                isLoadingRoute: false,
                canSave: true,
                isSaving: false,
                onSave: {}
            )
        }
    }
}

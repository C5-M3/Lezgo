//
//  TripSummarySection.swift
//  Lezgo
//
//  Created by Farrell Sudjatmiko on 26/10/26.
//

import CoreLocation
import SwiftUI

struct TripSummarySection: View {
    let isLoadingRoute: Bool
    let hasRoute: Bool
    let totalDistance: CLLocationDistance
    let totalDuration: TimeInterval

    var body: some View {
        if isLoadingRoute {
            HStack {
                Spacer()
                ProgressView()
                    .padding(.vertical, 8)
                Spacer()
            }
        } else if hasRoute {
            Section("Trip Summary") {
                HStack {
                    Label("Total Distance", systemImage: "arrow.triangle.turn.up.right.diamond")
                        .accessibilityHidden(true)
                    Spacer()
                    Text(String(format: "%.1f km", totalDistance / 1000))
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Label("Total Duration", systemImage: "clock")
                        .accessibilityHidden(true)
                    Spacer()
                    Text(formatDuration(totalDuration))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60

        if hours > 0 {
            return "\(hours) hr \(minutes) min"
        } else {
            return "\(minutes) min"
        }
    }
}

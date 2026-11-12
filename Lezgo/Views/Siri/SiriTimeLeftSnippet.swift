//
//  SiriTimeLeftSnippet.swift
//  Lezgo
//
//  Created by Nathan Sudiara on 12/11/26.
//

import SwiftUI

/// Siri's card for "How long left" (US-08): this car, the next checkpoint and the destination, with the distance to
/// each and the time and arrival at the destination.
struct SiriTimeLeftSnippet: View {
    /// What a row is, which sets its marker.
    enum StopKind: Hashable { case me, checkpoint, destination }

    struct Stop: Identifiable, Hashable {
        var id: StopKind { kind }
        var kind: StopKind
        var name: String
        /// "Checkpoint · 4.1 km", "Jalan Parangtritis".
        var subtitle: String?
        var timeLeft: Duration?
        var arrival: Date?
    }

    let stops: [Stop]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(stops) { stop in
                HStack(spacing: 12) {
                    Marker(kind: stop.kind)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(stop.name)
                            .font(.headline)
                        if let subtitle = stop.subtitle {
                            Text(subtitle)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer(minLength: 8)
                    if let timeLeft = stop.timeLeft {
                        VStack(alignment: .trailing, spacing: 1) {
                            Text(timeLeft.formatted(TripMapCarStatus.durationStyle))
                                .font(.title3.bold())
                                .monospacedDigit()
                            if let arrival = stop.arrival {
                                Text(arrival, format: .dateTime.hour().minute())
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .accessibilityElement(children: .combine)
            }
        }
        .padding()
    }

    private struct Marker: View {
        let kind: StopKind

        var body: some View {
            Group {
                switch kind {
                case .me:
                    Image(systemName: "location.fill")
                        .foregroundStyle(.white)
                        .frame(width: 30, height: 30)
                        .background(.blue, in: .circle)
                case .checkpoint:
                    Image(systemName: "mappin.circle.fill")
                        .font(.system(size: 30))
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, .orange)
                case .destination:
                    Image(systemName: "flag.checkered")
                        .foregroundStyle(Color(.brandYellow))
                        .frame(width: 30, height: 30)
                        .background(Color(.tripCard), in: .circle)
                }
            }
            .font(.footnote.bold())
            .accessibilityHidden(true)
        }
    }
}

#Preview {
    SiriTimeLeftSnippet(stops: [
        .init(kind: .me, name: "You", subtitle: "Jalan Parangtritis"),
        .init(kind: .checkpoint, name: "Rest Area KM 57", subtitle: "Checkpoint · 4.1 km"),
        .init(kind: .destination, name: "Pantai Parangtritis", subtitle: "Destination · 12 km",
              timeLeft: .seconds(840), arrival: .now.addingTimeInterval(840))
    ])
    .padding()
}

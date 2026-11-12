//
//  SiriTimeLeftSnippet.swift
//  Lezgo
//
//  Created by Nathan Sudiara on 12/11/26.
//

import SwiftUI

/// Siri's card for "How long left" (US-08): the next checkpoint and the destination with their distance, then the
/// time left and the arrival time on a line of their own, so a long place name never squeezes them.
struct SiriTimeLeftSnippet: View {
    /// What a row is, which sets its marker.
    enum StopKind: Hashable { case checkpoint, destination }

    struct Stop: Identifiable, Hashable {
        var id: StopKind { kind }
        var kind: StopKind
        var name: String
        /// "Checkpoint · 4.1 km", "Destination · 12 km".
        var subtitle: String?
    }

    let stops: [Stop]
    let timeLeft: Duration
    let arrival: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(stops) { stop in
                HStack(spacing: 10) {
                    Marker(kind: stop.kind)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(stop.name)
                            .font(.headline)
                            .lineLimit(2)
                        if let subtitle = stop.subtitle {
                            Text(subtitle)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                    Spacer(minLength: 0)
                }
                .accessibilityElement(children: .combine)
            }
            Label {
                Text(.siriTimeAndArrival(
                    timeLeft.formatted(TripMapCarStatus.durationStyle),
                    arrival.formatted(date: .omitted, time: .shortened)
                ))
            } icon: {
                Image(systemName: "clock.fill")
            }
            .font(.subheadline.weight(.semibold))
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.8)
        }
        .padding()
    }

    private struct Marker: View {
        let kind: StopKind

        var body: some View {
            Group {
                switch kind {
                case .checkpoint:
                    Image(systemName: "mappin")
                        .foregroundStyle(.white)
                        .background(Circle().fill(.orange).frame(width: 28, height: 28))
                case .destination:
                    Image(systemName: "flag.checkered")
                        .foregroundStyle(Color(.brandYellow))
                        .background(Circle().fill(Color(.tripCard)).frame(width: 28, height: 28))
                }
            }
            .font(.footnote.bold())
            .frame(width: 28, height: 28)
            .accessibilityHidden(true)
        }
    }
}

#Preview {
    SiriTimeLeftSnippet(
        stops: [
            .init(kind: .checkpoint, name: "Rest Area KM 57", subtitle: "Checkpoint · 4.1 km"),
            .init(kind: .destination, name: "Ciputra World Surabaya", subtitle: "Destination · 14 km")
        ],
        timeLeft: .seconds(2_400),
        arrival: .now.addingTimeInterval(2_400)
    )
}

#Preview("Largest text") {
    SiriTimeLeftSnippet(
        stops: [.init(kind: .destination, name: "Pantai Parangtritis", subtitle: "Destination · 12 km")],
        timeLeft: .seconds(840),
        arrival: .now.addingTimeInterval(840)
    )
    .dynamicTypeSize(.accessibility2)
}

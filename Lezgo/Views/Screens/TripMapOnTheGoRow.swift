//
//  TripMapOnTheGoRow.swift
//  Lezgo
//
//  Created by Oky Faishal on 18/11/26.
//

import SwiftUI

/// One participant on the On the Go list: the robot, the name, what the car is doing and where, the car, and when it
/// arrives (ADR 0034).
struct TripMapOnTheGoRow: View {
    let row: TripMapViewModel.ParticipantRow

    /// The mascot is drawn larger than the card and its feet are cut off, as in the hi-fi.
    private static let mascotImageSize = 130.0
    private static let mascotDrop = 18.0

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            Image(row.status.carColor.fullBodyImage)
                .resizable()
                .scaledToFit()
                .frame(width: Self.mascotImageSize, height: Self.mascotImageSize)
                .offset(y: Self.mascotDrop)
                .opacity(IsOffline() ? 0.4 : 1)
                .accessibilityHidden(true)

            // One line each: a long name or street is cut off with "…" instead of growing the card.
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: row.status.displayName)
                    .font(.title2.weight(.heavy))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(verbatim: row.status.statusLine)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(StatusColor())
                    .lineLimit(1)
                if row.status.carDescription.isEmpty == false {
                    Text(verbatim: row.status.carDescription)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color(.tripCardSubtext))
                        .lineLimit(1)
                }
                if let timeToDestination = row.timeToDestination {
                    Text(.tripMapOnTheGoArrivesIn(timeToDestination.formatted(TripMapCarStatus.durationStyle)))
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.leading, 4)
        .padding(.trailing, 16)
        .frame(height: 100)
        .clipShape(.rect(cornerRadius: LezgoRadius.card))
        .lezgoSurface(.level1, radius: LezgoRadius.card)
        .accessibilityElement(children: .combine)
    }

    /// Yellow while driving, red once stopped, white when offline. The words say the status too, so colour is never
    /// the only sign.
    private func StatusColor() -> Color {
        switch row.status.activity {
        case .driving: Color(.brandYellow)
        case .stopped: Color(.tripAlertRed)
        case .offline: Color(.tripCardText)
        }
    }

    private func IsOffline() -> Bool {
        if case .offline = row.status.activity { return true }
        return false
    }
}

#Preview("Driving, stopped and offline") {
    VStack {
        TripMapOnTheGoRow(row: .init(
            status: TripMapCarStatus(
                id: UUID(), displayName: "Oky", activity: .driving(street: "Jl. Adityawarman"),
                carDescription: "Black Toyota Innova"
            ),
            timeToDestination: .seconds(21 * 60), isMe: true
        ))
        TripMapOnTheGoRow(row: .init(
            status: TripMapCarStatus(
                id: UUID(), displayName: "Rizal", activity: .stopped(street: "Jl. Citra Niaga"),
                carDescription: "Black Toyota Avanza", carColor: .green
            ),
            timeToDestination: .seconds(51 * 60), isMe: false
        ))
        TripMapOnTheGoRow(row: .init(
            status: TripMapCarStatus(
                id: UUID(), displayName: "Bartholomew Alexander Wicaksono", activity: .offline(lastSeen: .seconds(180)),
                carColor: .pink
            ),
            timeToDestination: nil, isMe: false
        ))
    }
    .padding()
    .background(Color(.tripCard))
    .environment(\.colorScheme, .dark)
}

#Preview("Largest text") {
    TripMapOnTheGoRow(row: .init(
        status: TripMapCarStatus(
            id: UUID(), displayName: "Matthew", activity: .driving(street: "Jl. HR Mayjend Muhammad")
        ),
        timeToDestination: .seconds(26 * 60), isMe: false
    ))
    .padding()
    .background(Color(.tripCard))
    .environment(\.colorScheme, .dark)
    .dynamicTypeSize(.accessibility5)
}

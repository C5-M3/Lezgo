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

    /// The mascot's crest nearly touches the top of the card and its feet are cut off at the bottom, as in the hi-fi.
    private static let mascotImageSize = 150.0
    private static let mascotDrop = 8.0
    private static let mascotRoom = 134.0
    private static let rowHeight = 90.0

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            Image(row.status.carColor.fullBodyImage)
                .resizable()
                .scaledToFit()
                .frame(width: Self.mascotImageSize, height: Self.mascotImageSize)
                .offset(y: Self.mascotDrop)
                .opacity(IsOffline() ? 0.4 : 1)
                // The text starts where it does in the hi-fi; the image may be wider than this room.
                .frame(width: Self.mascotRoom)
                .accessibilityHidden(true)

            // One line each: a long name or street is cut off with "…" instead of growing the card.
            VStack(alignment: .leading, spacing: 2) {
                NameLine()
                Text(verbatim: row.status.statusLine)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(StatusColor())
                    .lineLimit(1)
                if row.status.carDescription.isEmpty == false {
                    Text(verbatim: row.status.carDescription)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Color(.tripCardSubtext))
                        .lineLimit(1)
                }
                if let timeToDestination = row.timeToDestination {
                    Text(.tripMapOnTheGoArrivesIn(timeToDestination.formatted(TripMapCarStatus.durationStyle)))
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                }
            }
            .padding(.trailing, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: Self.rowHeight)
        .clipShape(.rect(cornerRadius: LezgoRadius.card))
        .lezgoSurface(.level1, radius: LezgoRadius.card)
        .overlay {
            RoundedRectangle(cornerRadius: LezgoRadius.card)
                .strokeBorder(Color(.surfaceSeparator), lineWidth: 1)
        }
        .overlay(alignment: .topLeading) {
            // The crown sits on the card's corner, so it is outside the clip above.
            if row.isLeader {
                Image(systemName: "crown.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color(.brandYellow))
                    .offset(x: 12, y: -8)
                    .accessibilityHidden(true)
            }
        }
        .accessibilityElement(children: .combine)
    }

    /// The driver's name, with "(You)" beside this phone's own car.
    private func NameLine() -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text(verbatim: row.status.displayName)
                .font(.title2.weight(.heavy))
                .foregroundStyle(.white)
                .lineLimit(1)
            if row.isMe {
                Text(verbatim: "(\(String(localized: .tripMapCarYou)))")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color(.tripCardSubtext))
                    .lineLimit(1)
                    .layoutPriority(1)
            }
        }
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
            timeToDestination: .seconds(21 * 60), isMe: true, isLeader: true
        ))
        TripMapOnTheGoRow(row: .init(
            status: TripMapCarStatus(
                id: UUID(), displayName: "Rizal", activity: .stopped(street: "Jl. Citra Niaga"),
                carDescription: "Black Toyota Avanza", carColor: .green
            ),
            timeToDestination: .seconds(51 * 60), isMe: false, isLeader: false
        ))
        TripMapOnTheGoRow(row: .init(
            status: TripMapCarStatus(
                id: UUID(), displayName: "Bartholomew Alexander Wicaksono", activity: .offline(lastSeen: .seconds(180)),
                carColor: .pink
            ),
            timeToDestination: nil, isMe: false, isLeader: false
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
        timeToDestination: .seconds(26 * 60), isMe: false, isLeader: false
    ))
    .padding()
    .background(Color(.tripCard))
    .environment(\.colorScheme, .dark)
    .dynamicTypeSize(.accessibility5)
}

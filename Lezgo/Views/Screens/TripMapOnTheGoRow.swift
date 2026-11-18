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
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// Where the text starts and how tall the card is: a little further right than in the hi-fi, so the mascot's hand
    /// does not touch it.
    private static let textLeading = 150.0
    private static let rowHeight = 92.0
    /// The mascot's size and where its top left corner sits against the card's, measured from the hi-fi: the crest is
    /// just under the card's top edge and the legs reach past the bottom edge, which cuts them off.
    private static let mascotSize = CGSize(width: 138, height: 113.6)
    private static let mascotOffset = CGSize(width: -2, height: 3)
    /// At accessibility text sizes the text goes under the mascot, so it gets the card's whole width.
    private static let stackedTextTop = 112.0

    /// `true` at accessibility text sizes: the text wraps and goes under the mascot, and the card grows to fit it.
    private var isStacked: Bool { dynamicTypeSize.isAccessibilitySize }
    /// One line beside the mascot, as in the hi-fi; at accessibility sizes as many as the text needs, so nothing is
    /// cut off.
    private var lineLimit: Int? { isStacked ? nil : 1 }

    var body: some View {
        // One line each at the usual sizes: a long name or street is cut off with "…" instead of growing the card.
        VStack(alignment: .leading, spacing: 3) {
            NameLine()
            Text(verbatim: row.status.statusLine)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(StatusColor())
                .lineLimit(lineLimit)
            if row.status.carDescription.isEmpty == false {
                Text(verbatim: row.status.carDescription)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color(.tripCardSubtext))
                    .lineLimit(lineLimit)
            }
            if let timeToDestination = row.timeToDestination {
                Text(.tripMapOnTheGoArrivesIn(timeToDestination.formatted(TripMapCarStatus.durationStyle)))
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(Color(.tripCardText))
                    .lineLimit(lineLimit)
                    .padding(.top, 2)
            }
        }
        .padding(.leading, isStacked ? 18 : Self.textLeading)
        .padding(.trailing, 14)
        .padding(.top, isStacked ? Self.stackedTextTop : 0)
        .padding(.bottom, isStacked ? 16 : 0)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(minHeight: Self.rowHeight)
        .fixedSize(horizontal: false, vertical: true)
        // The mascot is taller than the card, so it is a background: it never changes the card's size, and the clip
        // below cuts it off at the card's edge.
        .background(alignment: .topLeading) {
            Image(row.status.carColor.onTheGoMascotImage)
                .resizable()
                .frame(width: Self.mascotSize.width, height: Self.mascotSize.height)
                .offset(x: Self.mascotOffset.width, y: Self.mascotOffset.height)
                .opacity(IsOffline() ? 0.4 : 1)
                .accessibilityHidden(true)
        }
        .clipShape(.rect(cornerRadius: LezgoRadius.card))
        .lezgoSurface(.page, radius: LezgoRadius.card)
        .overlay {
            RoundedRectangle(cornerRadius: LezgoRadius.card)
                .strokeBorder(Color(.surfaceSeparator), lineWidth: 1)
        }
        .overlay(alignment: .topLeading) {
            if row.isLeader {
                Image(systemName: "crown.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color(.brandYellow))
                    .padding(.leading, 16)
                    .padding(.top, 10)
                    .accessibilityHidden(true)
            }
        }
        .accessibilityElement(children: .combine)
    }

    /// The driver's name, with "(You)" beside this phone's own car.
    private func NameLine() -> some View {
        let layout = isStacked
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 0))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 4))
        return layout {
            Text(verbatim: row.status.displayName)
                .font(.title2.weight(.heavy))
                .foregroundStyle(.white)
                .lineLimit(lineLimit)
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
            id: UUID(), displayName: "Bartholomew Alexander", activity: .driving(street: "Jl. HR Mayjend Muhammad"),
            carDescription: "Yellow Honda Brio"
        ),
        timeToDestination: .seconds(26 * 60), isMe: true, isLeader: true
    ))
    .padding()
    .background(Color(.tripCard))
    .environment(\.colorScheme, .dark)
    .dynamicTypeSize(.accessibility5)
}

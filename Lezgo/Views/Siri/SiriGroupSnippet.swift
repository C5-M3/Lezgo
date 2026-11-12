//
//  SiriGroupSnippet.swift
//  Lezgo
//
//  Created by Nathan Sudiara on 12/11/26.
//

import SwiftUI

/// Siri's card for "Is everyone with me" (US-08): a bar of who is with the group, then one row per car with a
/// symbol and a word, so colour is never the only sign.
struct SiriGroupSnippet: View {
    struct Row: Identifiable, Hashable {
        let id: UUID
        var name: String
        var color: TripMapCarPin.CarColor
        var isLeader: Bool
        /// "1.2 km ahead", or the driver's name on this phone's own row.
        var subtitle: String?
        /// `nil` when the car is with the group.
        var reason: TripAnswers.Reason?
    }

    /// The leader first, then this phone's car, then the others, as on the map's car cards.
    let rows: [Row]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 4) {
                ForEach(rows) { row in
                    Capsule()
                        .fill(row.reason == nil ? Color.green : Color.orange)
                        .frame(height: 6)
                }
            }
            .accessibilityHidden(true)
            ForEach(rows) { row in
                if row.id != rows.first?.id {
                    Divider()
                }
                SiriGroupRow(row: row)
            }
        }
    }
}

/// One car on the "Is everyone with me" card.
private struct SiriGroupRow: View {
    let row: SiriGroupSnippet.Row

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) {
                Who(row: row)
                Spacer(minLength: 8)
                Status(reason: row.reason)
            }
            VStack(alignment: .leading, spacing: 6) {
                Who(row: row)
                Status(reason: row.reason)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private struct Who: View {
        let row: SiriGroupSnippet.Row

        var body: some View {
            HStack(spacing: 10) {
                SiriCarAvatar(color: row.color, isLeader: row.isLeader, size: 38)
                VStack(alignment: .leading, spacing: 1) {
                    Text(row.name)
                        .font(.headline)
                    if let subtitle = row.subtitle {
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private struct Status: View {
        let reason: TripAnswers.Reason?

        var body: some View {
            Label {
                Text(text)
            } icon: {
                Image(systemName: symbol)
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(color)
        }

        private var text: LocalizedStringResource {
            switch reason {
            case nil: .siriStatusWithGroup
            case .offRoute: .siriStatusOffRoute
            case .passedCheckpoint: .siriStatusPassedCheckpoint
            case .passedDestination: .siriStatusPassedDestination
            case .aheadOfLeader: .siriStatusAheadOfLeader
            case .offline: .siriStatusOffline
            }
        }

        private var symbol: String {
            switch reason {
            case nil: "checkmark.circle.fill"
            case .offline: "wifi.slash"
            default: "exclamationmark.triangle.fill"
            }
        }

        private var color: Color {
            switch reason {
            case nil: .green
            case .offline: .secondary
            default: .orange
            }
        }
    }
}

#Preview {
    SiriGroupSnippet(rows: [
        .init(id: UUID(), name: "Agus", color: .yellow, isLeader: true, subtitle: "1.2 km ahead", reason: nil),
        .init(id: UUID(), name: "You", color: .blue, isLeader: false, subtitle: "Budi", reason: nil),
        .init(id: UUID(), name: "Citra", color: .pink, isLeader: false, subtitle: "400 m behind", reason: .offRoute),
        .init(id: UUID(), name: "Dewi", color: .green, isLeader: false, subtitle: nil, reason: .offline)
    ])
    .padding()
}

#Preview("Largest text") {
    SiriGroupSnippet(rows: [
        .init(id: UUID(), name: "Citra", color: .pink, isLeader: false, subtitle: "400 m behind", reason: .offRoute)
    ])
    .padding()
    .dynamicTypeSize(.accessibility3)
}

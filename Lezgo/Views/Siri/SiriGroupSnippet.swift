//
//  SiriGroupSnippet.swift
//  Lezgo
//
//  Created by Nathan Sudiara on 12/11/26.
//

import SwiftUI

/// Siri's card for "Is everyone with me" (US-08): a bar of who is with the group, then one short row per car with a
/// symbol, so colour is never the only sign. Siri cards cannot scroll, so at most four cars show and the rest are
/// counted.
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

    /// The most rows that fit on a Siri card without scrolling.
    static let maxRows = 4

    /// Cars that are not with the group first, then the leader, this phone's car and the others.
    let rows: [Row]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                ForEach(rows) { row in
                    Capsule()
                        .fill(row.reason == nil ? Color.green : Color.orange)
                        .frame(height: 6)
                }
            }
            .accessibilityHidden(true)
            ForEach(rows.prefix(Self.maxRows)) { row in
                SiriGroupRow(row: row)
            }
            if rows.count > Self.maxRows {
                Text(.siriMoreCars(rows.count - Self.maxRows))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
    }
}

/// One car on the "Is everyone with me" card: its robot, name, distance and a status symbol with a short word.
private struct SiriGroupRow: View {
    let row: SiriGroupSnippet.Row

    var body: some View {
        HStack(spacing: 10) {
            SiriCarAvatar(color: row.color, isLeader: row.isLeader, size: 32)
            VStack(alignment: .leading, spacing: 0) {
                Text(row.name)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                if let subtitle = row.subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 8)
            Label {
                Text(text)
            } icon: {
                Image(systemName: symbol)
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(color)
            .lineLimit(1)
        }
        .accessibilityElement(children: .combine)
    }

    private var text: LocalizedStringResource {
        switch row.reason {
        case nil: .siriStatusWithGroup
        case .offRoute: .siriStatusOffRoute
        case .passedCheckpoint: .siriStatusPassedCheckpoint
        case .passedDestination: .siriStatusPassedDestination
        case .aheadOfLeader: .siriStatusAheadOfLeader
        case .offline: .siriStatusOffline
        }
    }

    private var symbol: String {
        switch row.reason {
        case nil: "checkmark.circle.fill"
        case .offline: "wifi.slash"
        default: "exclamationmark.triangle.fill"
        }
    }

    private var color: Color {
        switch row.reason {
        case nil: .green
        case .offline: .secondary
        default: .orange
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

//
//  TripRoomOverview.swift
//  Lezgo
//
//  Created by oky faishal on 05/11/26.
//

import SwiftUI

/// "Overview": the start point, the destination and how many checkpoints lie between them, with "Edit" for the
/// leader (US-04, "Room").
struct TripRoomOverview: View {
    let startName: String?
    let destinationName: String?
    let numberOfStops: Int
    /// Opens the route planner; `nil` for a member, who sees no "Edit".
    var onEdit: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Overview")
                    .font(.title3.bold())
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                if let onEdit {
                    Button(action: onEdit) {
                        // The frame is inside the label so the whole 44 pt square can be tapped.
                        Text("Edit")
                            .frame(minWidth: 44, minHeight: 44)
                            .contentShape(.rect)
                    }
                    .font(.headline)
                    .foregroundStyle(Color(.brandYellow))
                    .accessibilityLabel("Edit route")
                    // Voice Control users say what they see on screen.
                    .accessibilityInputLabels(["Edit", "Edit route"])
                }
            }
            // Side by side like the hi-fi; stacked when large text no longer fits in three columns.
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 16) { items }
                VStack(alignment: .leading, spacing: 16) { items }
            }
        }
    }

    @ViewBuilder private var items: some View {
        OverviewItem(systemImage: "house.fill", title: "STARTING POINT", value: startName ?? "–")
        OverviewItem(systemImage: "flag.checkered", title: "DESTINATION", value: destinationName ?? "–")
        OverviewItem(systemImage: "mappin.circle.fill", title: "# OF STOPS", value: numberOfStops.formatted())
    }
}

private struct OverviewItem: View {
    let systemImage: String
    let title: LocalizedStringKey
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: systemImage)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

#if DEBUG
#Preview("Overview") {
    TripRoomOverview(startName: "Universitas Ciputra", destinationName: "Tunjungan Plaza", numberOfStops: 6)
        .padding()
        .preferredColorScheme(.dark)
}

#Preview("Leader with Edit") {
    TripRoomOverview(
        startName: "Universitas Ciputra",
        destinationName: "Tunjungan Plaza",
        numberOfStops: 6,
        onEdit: {}
    )
    .padding()
    .preferredColorScheme(.dark)
}

#Preview("Long names, Accessibility XXXL") {
    TripRoomOverview(
        startName: "Jalan Raya Darmo Permai Selatan Nomor 203, Surabaya",
        destinationName: "Pakuwon Mall",
        numberOfStops: 0
    )
    .padding()
    .dynamicTypeSize(.accessibility5)
    .preferredColorScheme(.dark)
}
#endif

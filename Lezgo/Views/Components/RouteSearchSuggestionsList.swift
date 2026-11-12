//
//  RouteSearchSuggestionsList.swift
//  Lezgo
//
//  Created by Farrell Sudjatmiko on 05/11/26.
//

import CoreLocation
import SwiftUI

struct RouteSearchSuggestionsList: View {
    let searchResults: [SearchResultItem]
    let isSearching: Bool
    let searchQuery: String
    let selectionType: ActivePointSelection?
    let userLocation: CLLocationCoordinate2D?
    let onSelectCurrentLocation: () -> Void
    let onSelectResult: (SearchResultItem) -> Void

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                if selectionType == .start && userLocation != nil {
                    currentLocationRow
                    Divider().overlay(Color(white: 0.18))
                }

                if isSearching {
                    HStack {
                        Spacer()
                        ProgressView()
                            .tint(.white)
                            .padding(.vertical, 24)
                        Spacer()
                    }
                } else if searchResults.isEmpty && !hasEmptySearchQuery {
                    emptyResultsView
                } else {
                    ForEach(searchResults, id: \.self) { result in
                        suggestionRow(result)
                        Divider().overlay(Color(white: 0.18))
                    }
                }
            }
            .padding(.horizontal, 16)
        }
        .scrollDismissesKeyboard(.interactively)
        .scrollBounceBehavior(.basedOnSize)
    }

    private var hasEmptySearchQuery: Bool {
        searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var currentLocationRow: some View {
        quickOptionRow(
            systemImage: "location.fill",
            title: "Current Location",
            subtitle: "Use GPS position",
            action: onSelectCurrentLocation
        )
    }

    /// A row that picks a place without typing: a yellow icon in a gray circle, a title and one short line.
    private func quickOptionRow(
        systemImage: String,
        title: LocalizedStringKey,
        subtitle: LocalizedStringKey,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Circle()
                    .fill(Color(white: 0.18))
                    .frame(width: 42, height: 42)
                    .overlay(
                        Image(systemName: systemImage)
                            .font(.callout)
                            .foregroundStyle(Color(.brandYellow))
                            .accessibilityHidden(true)
                    )

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(Color(white: 0.6))
                }

                Spacer()
            }
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func suggestionRow(_ result: SearchResultItem) -> some View {
        Button {
            onSelectResult(result)
        } label: {
            HStack(spacing: 14) {
                Circle()
                    .fill(Color(white: 0.18))
                    .frame(width: 42, height: 42)
                    .overlay(
                        Image(systemName: "mappin")
                            .font(.callout)
                            .foregroundStyle(.white)
                            .accessibilityHidden(true)
                    )

                VStack(alignment: .leading, spacing: 3) {
                    Text(result.title)
                        .font(.headline)
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    if !result.subtitle.isEmpty {
                        Text(result.subtitle)
                            .font(.caption)
                            .foregroundStyle(Color(white: 0.6))
                            .lineLimit(2)
                    }
                }

                Spacer()

                if let meters = result.distanceInMeters {
                    Text(FormattedDistance(meters))
                        .font(.subheadline)
                        .foregroundStyle(Color(white: 0.65))
                } else if result.isCalculatingDistance {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white.opacity(0.15))
                        .frame(width: 44, height: 14)
                        .redacted(reason: .placeholder)
                }
            }
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var emptyResultsView: some View {
        VStack(spacing: 10) {
            Spacer().frame(height: 32)
            Image(systemName: "magnifyingglass")
                .font(.largeTitle)
                .foregroundStyle(Color(white: 0.5))
                .accessibilityHidden(true)
            Text("No places found. Check the spelling.")
                .font(.subheadline)
                .foregroundStyle(Color(white: 0.65))
            Spacer().frame(height: 32)
        }
    }

    private func FormattedDistance(_ meters: CLLocationDistance) -> String {
        if meters < 1000 {
            return "\(Int(meters)) m"
        } else {
            let km = meters / 1000.0
            if km < 10 {
                return String(format: "%.1f km", km)
            } else {
                return "\(Int(round(km))) km"
            }
        }
    }
}

#Preview {
    ZStack {
        Color(red: 18 / 255, green: 18 / 255, blue: 20 / 255).ignoresSafeArea()
        RouteSearchSuggestionsList(
            searchResults: [
                SearchResultItem(
                    id: "1",
                    title: "Monumen Kapal Selam",
                    subtitle: "Jl. Pemuda No.39, Embong Kaliasin",
                    completion: nil,
                    distanceInMeters: 20000
                ),
                SearchResultItem(
                    id: "2",
                    title: "Monumen Kapal Selam Parking",
                    subtitle: "Jl. Pemuda, Genteng",
                    completion: nil,
                    distanceInMeters: 20000
                ),
                SearchResultItem(
                    id: "3",
                    title: "Monumen Tugu Pahlawan",
                    subtitle: "Jl. Pahlawan, Alun-alun Contong",
                    completion: nil,
                    distanceInMeters: 22000
                )
            ],
            isSearching: false,
            searchQuery: "Monumen",
            selectionType: .destination(index: 0),
            userLocation: CLLocationCoordinate2D(latitude: -7.25, longitude: 112.75),
            onSelectCurrentLocation: {},
            onSelectResult: { _ in }
        )
    }
}

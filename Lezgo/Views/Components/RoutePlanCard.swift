//
//  RoutePlanCard.swift
//  Lezgo
//
//  Created by Farrell Sudjatmiko on 05/11/26.
//

import SwiftUI

struct RoutePlanCard: View {
    let startPoint: RoutePoint?
    let destinations: [RoutePoint]
    let activeSelection: ActivePointSelection?
    @Binding var searchQuery: String
    let isStartPointLocked: Bool
    @Binding var isStopsExpanded: Bool
    let onSelectPointForEditing: (ActivePointSelection) -> Void
    let onClearSearch: () -> Void
    let onAddDestination: () -> Void
    let onRemoveDestination: (Int) -> Void
    let onMoveDestination: ((IndexSet, Int) -> Void)?

    @FocusState var isFieldFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            startPointRow

            if !intermediateStops.isEmpty {
                connectingLine
                intermediateStopsSection
                connectingLine
            } else if !destinations.isEmpty || isSearchingDestination {
                connectingLine
            }

            destinationRow

            Divider()
                .overlay(Color(white: 0.22))
                .padding(.vertical, 12)

            addDestinationRow
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(red: 26 / 255, green: 26 / 255, blue: 28 / 255))
        )
        .shadow(color: .black.opacity(0.35), radius: 14, x: 0, y: 6)
        .padding(.horizontal, 16)
        .onChange(of: activeSelection) { _, newActive in
            if newActive != nil {
                isFieldFocused = true
            }
        }
    }
}

// MARK: - Internal Helpers

extension RoutePlanCard {
    var isAddingNewDestination: Bool {
        guard let activeSelection = activeSelection else { return false }
        if case .destination(let index) = activeSelection {
            return index >= destinations.count
        }
        return false
    }

    var intermediateStops: [RoutePoint] {
        if isAddingNewDestination {
            return destinations
        } else if destinations.count > 1 {
            return Array(destinations.dropLast())
        } else {
            return []
        }
    }

    var isSearchingDestination: Bool {
        guard let activeSelection = activeSelection else { return false }
        switch activeSelection {
        case .start:
            return false
        case .destination(let index):
            if isAddingNewDestination {
                return true
            }
            if destinations.isEmpty {
                return index == 0
            }
            return index == destinations.count - 1
        }
    }
}

// MARK: - Subviews

private extension RoutePlanCard {
    var startPointRow: some View {
        HStack(spacing: 12) {
            Image(systemName: "house.fill")
                .font(.system(size: 16))
                .foregroundStyle(Color.heroYellow)
                .frame(width: 24, height: 24)
                .accessibilityHidden(true)

            if activeSelection == .start {
                searchTextField(placeholder: "Search starting point")
            } else {
                Button {
                    if !isStartPointLocked {
                        onSelectPointForEditing(.start)
                    }
                } label: {
                    HStack {
                        Text(startPoint?.name ?? String(localized: .waypointCurrentLocation))
                            .font(.system(size: 15))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        Spacer()
                        if !isStartPointLocked {
                            Image(systemName: "line.3.horizontal")
                                .font(.system(size: 14))
                                .foregroundStyle(Color(white: 0.35))
                                .accessibilityHidden(true)
                        }
                    }
                    .frame(minHeight: 28)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(isStartPointLocked)
            }
        }
    }

    @ViewBuilder
    var intermediateStopsSection: some View {
        let count = intermediateStops.count

        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                isStopsExpanded.toggle()
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "mappin.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(Color.heroYellow)
                    .frame(width: 24, height: 24)
                    .accessibilityHidden(true)

                Text(count == 1 ? "1 stop" : "\(count) stops")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color.heroYellow)

                Spacer()

                Image(systemName: isStopsExpanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.heroYellow)
                    .accessibilityHidden(true)
            }
            .frame(minHeight: 28)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)

        if isStopsExpanded {
            ForEach(Array(intermediateStops.enumerated()), id: \.element.id) { index, stop in
                connectingLine

                HStack(spacing: 12) {
                    Image(systemName: "mappin.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(Color.heroYellow)
                        .frame(width: 24, height: 24)
                        .accessibilityHidden(true)

                    if activeSelection == .destination(index: index) {
                        searchTextField(placeholder: "Search stop")
                    } else {
                        Button {
                            onSelectPointForEditing(.destination(index: index))
                        } label: {
                            HStack {
                                Text(stop.name)
                                    .font(.system(size: 15))
                                    .foregroundStyle(.white)
                                    .lineLimit(1)
                                Spacer()
                                Image(systemName: "line.3.horizontal")
                                    .font(.system(size: 14))
                                    .foregroundStyle(Color(white: 0.35))
                                    .accessibilityHidden(true)
                            }
                            .frame(minHeight: 28)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button(role: .destructive) {
                                onRemoveDestination(index)
                            } label: {
                                Label("Delete Stop", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    var destinationRow: some View {
        let lastIndex = isAddingNewDestination ? destinations.count : destinations.indices.last
        let isEditingThisDestination = isSearchingDestination

        HStack(spacing: 12) {
            Image(systemName: "flag.checkered")
                .font(.system(size: 16))
                .foregroundStyle(Color.heroYellow)
                .frame(width: 24, height: 24)
                .accessibilityHidden(true)

            if isEditingThisDestination {
                searchTextField(placeholder: "Where to?")
            } else {
                Button {
                    let targetIndex = lastIndex ?? 0
                    onSelectPointForEditing(.destination(index: targetIndex))
                } label: {
                    HStack {
                        Text(destinations.last?.name ?? "Choose destination...")
                            .font(.system(size: 15))
                            .foregroundStyle(destinations.isEmpty ? Color(white: 0.5) : .white)
                            .lineLimit(1)
                        Spacer()
                        if !destinations.isEmpty {
                            Image(systemName: "line.3.horizontal")
                                .font(.system(size: 14))
                                .foregroundStyle(Color(white: 0.35))
                                .accessibilityHidden(true)
                        }
                    }
                    .frame(minHeight: 28)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .contextMenu {
                    if let lastIndex = lastIndex {
                        Button(role: .destructive) {
                            onRemoveDestination(lastIndex)
                        } label: {
                            Label("Delete Destination", systemImage: "trash")
                        }
                    }
                }
            }
        }
    }

    var addDestinationRow: some View {
        Button(action: onAddDestination) {
            HStack(spacing: 12) {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.heroYellow)
                    .frame(width: 24, height: 24)
                    .accessibilityHidden(true)

                Text("Add Destination")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color.heroYellow)

                Spacer()
            }
            .frame(minHeight: 28)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    var connectingLine: some View {
        HStack(spacing: 0) {
            Rectangle()
                .fill(Color.heroYellow.opacity(0.85))
                .frame(width: 1.5, height: 16)
                .padding(.leading, 11)
            Spacer()
        }
    }

    func searchTextField(placeholder: String) -> some View {
        HStack(spacing: 8) {
            TextField(placeholder, text: $searchQuery)
                .font(.system(size: 15))
                .foregroundStyle(.white)
                .focused($isFieldFocused)
                .autocorrectionDisabled()
                .submitLabel(.search)

            if !searchQuery.isEmpty {
                Button(action: onClearSearch) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(Color(white: 0.55))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search text")
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 38)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.heroYellow, lineWidth: 1.5)
        )
    }
}

#Preview("Route Plan Card") {
    ZStack {
        Color.black.ignoresSafeArea()
        RoutePlanCard(
            startPoint: RoutePoint(name: "Universitas Ciputra", subtitle: "", coordinate: .init()),
            destinations: [RoutePoint(name: "Ciputra World Surabaya", subtitle: "", coordinate: .init())],
            activeSelection: nil,
            searchQuery: .constant(""),
            isStartPointLocked: false,
            isStopsExpanded: .constant(false),
            onSelectPointForEditing: { _ in },
            onClearSearch: {},
            onAddDestination: {},
            onRemoveDestination: { _ in },
            onMoveDestination: nil
        )
    }
}

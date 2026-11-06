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
        List {
            startPointRow
                .listRowInsets(EdgeInsets(top: 14, leading: 16, bottom: 6, trailing: 16))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)

            if !intermediateStops.isEmpty {
                intermediateStopsSection
            }

            if !isStopsExpanded {
                destinationRow
                    .listRowInsets(EdgeInsets(
                        top: 6,
                        leading: 16,
                        bottom: canAddDestination ? 6 : 14,
                        trailing: 16
                    ))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }

            if canAddDestination {
                addDestinationRow
                    .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 14, trailing: 16))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .environment(\.defaultMinListRowHeight, 0)
        .scrollDisabled(!isStopsExpanded || intermediateStops.count <= 4)
        .frame(height: calculatedHeight)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(red: 26 / 255, green: 26 / 255, blue: 28 / 255))
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
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
    var canAddDestination: Bool {
        !destinations.isEmpty && activeSelection == nil
    }

    var isAddingNewDestination: Bool {
        guard let activeSelection = activeSelection else { return false }
        if case .destination(let index) = activeSelection {
            return index >= destinations.count
        }
        return false
    }

    var intermediateStops: [RoutePoint] {
        if isAddingNewDestination || isStopsExpanded {
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

    var showsStartConnectingLine: Bool {
        !destinations.isEmpty || isSearchingDestination
    }

    var calculatedHeight: CGFloat {
        var height: CGFloat = showsStartConnectingLine ? 56 : 52
        if !intermediateStops.isEmpty {
            if isStopsExpanded {
                height += 60
                let stopsHeight = CGFloat(intermediateStops.count) * 44
                height += min(stopsHeight, 192)
            } else {
                height += 44
            }
        }
        if !isStopsExpanded {
            height += isSearchingDestination ? 52 : 44
        }
        if canAddDestination {
            height += 50
        }
        return height + 14
    }
}

// MARK: - Subviews

extension RoutePlanCard {
    var startPointRow: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 12) {
                ZStack {
                    if showsStartConnectingLine {
                        VStack(spacing: 0) {
                            Spacer(minLength: 0)
                            Rectangle()
                                .fill(Color.heroYellow.opacity(0.85))
                                .frame(width: 1.5, height: 20)
                        }
                    }

                    Image(systemName: "house.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(Color.heroYellow)
                        .background(Color(red: 26 / 255, green: 26 / 255, blue: 28 / 255))
                        .frame(width: 24, height: 24)
                        .accessibilityHidden(true)
                }
                .frame(width: 24)

                if activeSelection == .start {
                    searchTextField(placeholder: "Search starting point")
                } else {
                    Button {
                        if !isStartPointLocked {
                            onSelectPointForEditing(.start)
                        }
                    } label: {
                        Text(startPoint?.name ?? String(localized: .waypointCurrentLocation))
                            .font(.system(size: 15))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .frame(minHeight: 28)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(isStartPointLocked)
                }
            }
            .frame(minHeight: 36)

            if !destinations.isEmpty || isSearchingDestination {
                Divider()
                    .overlay(Color(white: 0.22))
                    .padding(.leading, 36)
            }
        }
    }

    @ViewBuilder
    var intermediateStopsSection: some View {
        let count = intermediateStops.count

        if count == 1, let singleStop = intermediateStops.first {
            stopRow(index: 0, stop: singleStop)
                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
        } else if count > 1 {
            stopsToggleRow
                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)

            if isStopsExpanded {
                ForEach(Array(intermediateStops.enumerated()), id: \.element.id) { index, stop in
                    let isLast = index == intermediateStops.count - 1
                    let bottomInset: CGFloat = (isLast && !canAddDestination) ? 20 : 6
                    stopRow(index: index, stop: stop)
                        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: bottomInset, trailing: 16))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
                .onDelete { indexSet in
                    for index in indexSet.sorted().reversed() {
                        onRemoveDestination(index)
                    }
                }
                .onMove { fromOffsets, toOffset in
                    onMoveDestination?(fromOffsets, toOffset)
                }
            }
        }
    }

    @ViewBuilder
    var destinationRow: some View {
        let lastIndex = isAddingNewDestination ? destinations.count : destinations.indices.last
        let isEditingThisDestination = isSearchingDestination

        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 12) {
                ZStack {
                    VStack(spacing: 0) {
                        Rectangle()
                            .fill(Color.heroYellow.opacity(0.85))
                            .frame(width: 1.5, height: 18)
                        Spacer(minLength: 0)
                    }

                    Image(systemName: "flag.checkered")
                        .font(.system(size: 16))
                        .foregroundStyle(Color.heroYellow)
                        .background(Color(red: 26 / 255, green: 26 / 255, blue: 28 / 255))
                        .frame(width: 24, height: 24)
                        .accessibilityHidden(true)
                }
                .frame(width: 24)

                if isEditingThisDestination {
                    searchTextField(placeholder: "Where to?")
                } else {
                    Button {
                        let targetIndex = lastIndex ?? 0
                        onSelectPointForEditing(.destination(index: targetIndex))
                    } label: {
                        Text(destinations.last?.name ?? "Choose destination...")
                            .font(.system(size: 15))
                            .foregroundStyle(destinations.isEmpty ? Color(white: 0.5) : .white)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .frame(minHeight: 28)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    if !destinations.isEmpty {
                        Image(systemName: "line.3.horizontal")
                            .font(.system(size: 14))
                            .foregroundStyle(Color(white: 0.35))
                            .frame(width: 28, height: 28)
                            .contentShape(Rectangle())
                            .accessibilityLabel("Reorder")
                    }
                }
            }
            .frame(minHeight: 36)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            if let lastIndex = lastIndex, !destinations.isEmpty {
                Button(role: .destructive) {
                    onRemoveDestination(lastIndex)
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
        .modifier(
            PointDragDropModifier(
                point: destinations.last,
                index: lastIndex,
                destinations: destinations,
                onMoveDestination: onMoveDestination
            )
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

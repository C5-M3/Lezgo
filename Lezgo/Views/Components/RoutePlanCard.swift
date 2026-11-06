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
                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)

            if showsConnectingLineAfterStart {
                RouteConnectingLine()
                    .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }

            if !intermediateStops.isEmpty {
                intermediateStopsSection

                RouteConnectingLine()
                    .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }

            destinationRow
                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)

            if canAddDestination {
                RouteAddDestinationRow(onAddDestination: onAddDestination)
                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .environment(\.defaultMinListRowHeight, 0)
        .scrollDisabled(!isStopsExpanded || intermediateStops.count <= 3)
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

    var showsConnectingLineAfterStart: Bool {
        !destinations.isEmpty || isSearchingDestination
    }

    var calculatedHeight: CGFloat {
        var height: CGFloat = 40
        if showsConnectingLineAfterStart {
            height += 16
        }
        if intermediateStops.count == 1 {
            height += 40 + 16
        } else if intermediateStops.count > 1 {
            height += 40 + 16
            if isStopsExpanded {
                let stopsCount = CGFloat(intermediateStops.count)
                let expandedStopsHeight = stopsCount * 40 + max(0, stopsCount - 1) * 16
                height += min(expandedStopsHeight, 200)
            }
        }
        height += 40
        if canAddDestination {
            height += 56
        }
        height += 16
        return height
    }

    func MoveDestinationItem(from fromIndex: Int, to toIndex: Int) {
        guard destinations.indices.contains(fromIndex),
              toIndex >= 0, toIndex <= destinations.count else { return }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            onMoveDestination?(IndexSet(integer: fromIndex), toIndex)
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
                RouteSearchField(
                    placeholder: "Search starting point",
                    text: $searchQuery,
                    isFocused: $isFieldFocused,
                    onClear: onClearSearch
                )
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
                    RouteConnectingLine()
                        .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)

                    stopRow(index: index, stop: stop)
                        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
            }
        }
    }

    var stopsToggleRow: some View {
        let count = intermediateStops.count

        return Button {
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

                Text("\(count) stops")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color.heroYellow)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(minHeight: 28)

                Image(systemName: isStopsExpanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.heroYellow)
                    .frame(width: 28, height: 28)
                    .accessibilityHidden(true)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    func stopRow(index: Int, stop: RoutePoint) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "mappin.circle.fill")
                .font(.system(size: 16))
                .foregroundStyle(Color.heroYellow)
                .frame(width: 24, height: 24)
                .accessibilityHidden(true)

            if activeSelection == .destination(index: index) {
                RouteSearchField(
                    placeholder: "Search stop",
                    text: $searchQuery,
                    isFocused: $isFieldFocused,
                    onClear: onClearSearch
                )
            } else {
                Button {
                    onSelectPointForEditing(.destination(index: index))
                } label: {
                    Text(stop.name)
                        .font(.system(size: 15))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .frame(minHeight: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                RouteReorderHandle(index: index, count: destinations.count, onMove: MoveDestinationItem)
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                onRemoveDestination(index)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .draggable(stop.id.uuidString)
        .dropDestination(for: String.self) { items, _ in
            handleDrop(items: items, targetIndex: index)
        }
    }

    @ViewBuilder
    var destinationRow: some View {
        let lastIndex = isAddingNewDestination ? destinations.count : (destinations.count - 1)
        let isEditingThisDestination = isSearchingDestination

        HStack(spacing: 12) {
            Image(systemName: "flag.checkered")
                .font(.system(size: 16))
                .foregroundStyle(Color.heroYellow)
                .frame(width: 24, height: 24)
                .accessibilityHidden(true)

            if isEditingThisDestination {
                RouteSearchField(
                    placeholder: "Where to?",
                    text: $searchQuery,
                    isFocused: $isFieldFocused,
                    onClear: onClearSearch
                )
            } else {
                Button {
                    onSelectPointForEditing(.destination(index: max(0, lastIndex)))
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

                if destinations.count > 1 {
                    RouteReorderHandle(index: lastIndex, count: destinations.count, onMove: MoveDestinationItem)
                }
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            if !destinations.isEmpty && lastIndex < destinations.count {
                Button(role: .destructive) {
                    onRemoveDestination(lastIndex)
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
        .draggable(destinations.last?.id.uuidString ?? "")
        .dropDestination(for: String.self) { items, _ in
            handleDrop(items: items, targetIndex: lastIndex)
        }
    }

    func handleDrop(items: [String], targetIndex: Int) -> Bool {
        guard let draggedID = items.first,
              let fromIndex = destinations.firstIndex(where: { $0.id.uuidString == draggedID }),
              fromIndex != targetIndex else {
            return false
        }
        let toOffset = targetIndex > fromIndex ? targetIndex + 1 : targetIndex
        MoveDestinationItem(from: fromIndex, to: toOffset)
        return true
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

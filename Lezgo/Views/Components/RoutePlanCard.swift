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
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    @FocusState var isFieldFocused: Bool
    /// The height of the rows, measured by the list. It starts at one row's height: a list with no height lays out
    /// no rows, so it would never measure them.
    @State private var contentHeight: CGFloat = 56
    /// The first measurement sets the height at once; only later changes (stops opening, closing, added) move.
    @State private var hasMeasuredHeight = false
    /// About five rows; more stops scroll inside the card so the map stays visible.
    private static let maximumHeight: CGFloat = 392

    var body: some View {
        List {
            let startInsets = EdgeInsets(top: 14, leading: 16, bottom: 6, trailing: 16)
            startPointRow
                .listRowInsets(startInsets)
                .listRowBackground(ConnectorLine(reachesUp: false, reachesDown: true, insets: startInsets))
                .listRowSeparator(.hidden)

            if showsStopsToggle {
                let toggleInsets = EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16)
                stopsToggleRow
                    .listRowInsets(toggleInsets)
                    .listRowBackground(ConnectorLine(reachesUp: true, reachesDown: true, insets: toggleInsets))
                    .listRowSeparator(.hidden)
            }

            if !listedRows.isEmpty {
                listedRowsSection
            }

            if showsDestinationRow {
                let destinationBottom: CGFloat = canAddDestination ? 6 : 14
                let destinationInsets = EdgeInsets(top: 6, leading: 16, bottom: destinationBottom, trailing: 16)
                destinationRow
                    .listRowInsets(destinationInsets)
                    .listRowBackground(ConnectorLine(reachesUp: true, reachesDown: false, insets: destinationInsets))
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
        // The card is as tall as its rows, so it fits every state and text size; past `maximumHeight` it scrolls.
        .onScrollGeometryChange(for: CGFloat.self) { $0.contentSize.height } action: { _, height in
            // The list reports no rows before it has laid them out; keeping that would hide them for good.
            guard height > 0 else { return }
            // The measurement arrives after the button's own animation ended, so the card moves with the rows here.
            let animation = hasMeasuredHeight ? Animation.lezgoPanel.Respecting(reduceMotion: reduceMotion) : nil
            withAnimation(animation) { contentHeight = height }
            hasMeasuredHeight = true
        }
        .scrollDisabled(contentHeight <= Self.maximumHeight)
        .frame(height: min(contentHeight, Self.maximumHeight))
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.routeCard))
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.35), radius: 14, x: 0, y: 6)
        .padding(.horizontal, 16)
        .onChange(of: activeSelection) { _, newActive in
            if newActive != nil {
                isFieldFocused = true
            }
        }
        // Set Route opens as a full screen cover already searching, and focus set while the cover is still sliding
        // in is dropped. Ask again once it has settled, so the keyboard is up without a tap.
        .task {
            try? await Task.sleep(for: .milliseconds(600))
            if !Task.isCancelled, activeSelection != nil {
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

    /// The stops between the start and the destination: every destination but the last, or every destination while
    /// a new one is being added, since the new one becomes the destination.
    var intermediateStops: [RoutePoint] {
        isAddingNewDestination ? destinations : Array(destinations.dropLast())
    }

    /// Two or more stops fold into one "N stops" row that opens and closes.
    var showsStopsToggle: Bool {
        intermediateStops.count >= 2
    }

    /// Whether the folded stops are open. Fewer than two stops have no fold, whatever was opened before.
    var isShowingAllStops: Bool {
        isStopsExpanded && showsStopsToggle
    }

    /// The destinations drawn one row each, in one list so they can be reordered by dragging: none while the stops
    /// are folded, otherwise every destination (while adding, they are all stops and the search field follows).
    var listedRows: [RoutePoint] {
        if intermediateStops.isEmpty || (showsStopsToggle && !isShowingAllStops) { return [] }
        return destinations
    }

    /// Whether `listedRows[index]` is the destination, drawn with the flag.
    func IsFinalDestination(index: Int) -> Bool {
        !isAddingNewDestination && index == destinations.count - 1
    }

    /// The last row on its own: the destination under folded stops, the search field while adding, or the only
    /// destination.
    var showsDestinationRow: Bool {
        listedRows.isEmpty || isAddingNewDestination
    }

    /// One destination has nothing to swap with.
    var showsDestinationReorderHandle: Bool {
        destinations.count > 1
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

    var showsStartDivider: Bool {
        !destinations.isEmpty || isSearchingDestination
    }
}

// MARK: - Subviews

extension RoutePlanCard {
    var startPointRow: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 12) {
                ZStack {

                    Image(systemName: "house.fill")
                        .font(.callout)
                        .foregroundStyle(Color(.brandYellow))
                        .background(Color(.routeCard))
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
                            .font(.subheadline)
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
            .padding(.vertical, 4)

            if showsStartDivider {
                Divider()
                    .overlay(Color(white: 0.22))
                    .padding(.leading, 36)
            }
        }
    }

    var listedRowsSection: some View {
        ForEach(Array(listedRows.enumerated()), id: \.element.id) { index, stop in
            let isLast = index == listedRows.count - 1
            let bottomInset: CGFloat = (isLast && !showsDestinationRow && !canAddDestination) ? 14 : 6
            let insets = EdgeInsets(top: 6, leading: 16, bottom: bottomInset, trailing: 16)
            stopRow(index: index, stop: stop)
                .listRowInsets(insets)
                .listRowBackground(
                    ConnectorLine(reachesUp: true, reachesDown: !IsFinalDestination(index: index), insets: insets)
                )
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

    @ViewBuilder
    var destinationRow: some View {
        let lastIndex = isAddingNewDestination ? destinations.count : destinations.indices.last
        let isEditingThisDestination = isSearchingDestination

        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 12) {
                ZStack {

                    Image(systemName: "flag.checkered")
                        .font(.callout)
                        .foregroundStyle(Color(.brandYellow))
                        .background(Color(.routeCard))
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
                            .font(.subheadline)
                            .foregroundStyle(destinations.isEmpty ? Color(white: 0.5) : .white)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .frame(minHeight: 28)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    if showsDestinationReorderHandle {
                        Image(systemName: "line.3.horizontal")
                            .font(.subheadline)
                            .foregroundStyle(Color(white: 0.35))
                            .frame(width: 28, height: 28)
                            .contentShape(Rectangle())
                            .accessibilityLabel("Reorder")
                    }
                }
            }
            .frame(minHeight: 36)
            .padding(.vertical, 4)
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

//
//  RoutePlanCard+Rows.swift
//  Lezgo
//
//  Created by Farrell Sudjatmiko on 06/11/26.
//

import SwiftUI

extension RoutePlanCard {
    var stopsToggleRow: some View {
        let count = intermediateStops.count

        return Button {
            withAnimation(Animation.lezgoPanel.Respecting(reduceMotion: reduceMotion)) {
                isStopsExpanded.toggle()
            }
        } label: {
            VStack(spacing: 0) {
                HStack(alignment: .center, spacing: 12) {
                    ZStack {
                        ConnectorLine(reachesUp: true, reachesDown: true)

                        Image(systemName: "mappin.circle.fill")
                            .font(.callout)
                            .foregroundStyle(Color(.brandYellow))
                            .background(Color(.routeCard))
                            .frame(width: 24, height: 24)
                            .accessibilityHidden(true)
                    }
                    .frame(width: 24)

                    Text("\(count) stops")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color(.brandYellow))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .frame(minHeight: 28)

                    Image(systemName: isShowingAllStops ? "chevron.up" : "chevron.down")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Color(.brandYellow))
                        .frame(width: 28, height: 28)
                        .accessibilityHidden(true)
                }
                .frame(minHeight: 36)
                .padding(.vertical, 4)

                Divider()
                    .overlay(Color(white: 0.22))
                    .padding(.leading, 36)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    func stopRow(index: Int, stop: RoutePoint) -> some View {
        let isFinalDestination = IsFinalDestination(index: index)

        return VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 12) {
                stopRowLeadingIndicator(isFinalDestination: isFinalDestination)

                if activeSelection == .destination(index: index) {
                    searchTextField(placeholder: isFinalDestination ? "Where to?" : "Search stop")
                } else {
                    stopRowContent(index: index, stop: stop)
                }
            }
            .frame(minHeight: 36)
            .padding(.vertical, 4)

            if !(isFinalDestination && !canAddDestination) {
                Divider()
                    .overlay(Color(white: 0.22))
                    .padding(.leading, 36)
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                onRemoveDestination(index)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .modifier(
            PointDragDropModifier(
                point: stop,
                index: index,
                destinations: destinations,
                onMoveDestination: onMoveDestination
            )
        )
    }

    private func stopRowLeadingIndicator(isFinalDestination: Bool) -> some View {
        ZStack {
            ConnectorLine(reachesUp: true, reachesDown: !isFinalDestination)

            Image(systemName: isFinalDestination ? "flag.checkered" : "mappin.circle.fill")
                .font(.callout)
                .foregroundStyle(Color(.brandYellow))
                .background(Color(.routeCard))
                .frame(width: 24, height: 24)
                .accessibilityHidden(true)
        }
        .frame(width: 24)
    }

    private func stopRowContent(index: Int, stop: RoutePoint) -> some View {
        HStack {
            Button {
                onSelectPointForEditing(.destination(index: index))
            } label: {
                Text(stop.name)
                    .font(.subheadline)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(minHeight: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Image(systemName: "line.3.horizontal")
                .font(.subheadline)
                .foregroundStyle(Color(white: 0.35))
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
                .accessibilityLabel("Reorder")
        }
    }

    var addDestinationRow: some View {
        Button {
            withAnimation(Animation.lezgoPanel.Respecting(reduceMotion: reduceMotion)) {
                isStopsExpanded = false
            }
            onAddDestination()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "plus")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color(.brandYellow))
                    .frame(width: 24, height: 24)
                    .accessibilityHidden(true)

                Text("Add Destination")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color(.brandYellow))

                Spacer()
            }
            .frame(minHeight: 28)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    func searchTextField(placeholder: String) -> some View {
        HStack(spacing: 8) {
            TextField(placeholder, text: $searchQuery)
                .font(.subheadline)
                .foregroundStyle(.white)
                .focused($isFieldFocused)
                .autocorrectionDisabled()
                .submitLabel(.search)

            if !searchQuery.isEmpty {
                Button(action: onClearSearch) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.callout)
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
                .strokeBorder(Color(.brandYellow), lineWidth: 1.5)
        )
    }
}

extension RoutePlanCard {
    /// The line joining the route's icons, drawn behind one icon. Each piece reaches past its row's padding and list
    /// inset to the row's edge, so the pieces of neighbouring rows meet in one unbroken line, as in the HiFi.
    struct ConnectorLine: View {
        let reachesUp: Bool
        let reachesDown: Bool
        /// The row has a divider under its content, which the piece going down crosses too.
        var crossesDivider = true
        @Environment(\.pixelLength) private var pixelLength

        /// From a row's content to its edge: the content's vertical padding (4) and the list row inset (6).
        private static let distanceToRowEdge: CGFloat = 10

        var body: some View {
            VStack(spacing: 0) {
                Piece(isDrawn: reachesUp)
                Piece(isDrawn: reachesDown)
            }
            .padding(.top, -Self.distanceToRowEdge)
            .padding(.bottom, -(Self.distanceToRowEdge + (crossesDivider ? pixelLength : 0)))
            .accessibilityHidden(true)
        }

        private func Piece(isDrawn: Bool) -> some View {
            Rectangle()
                .fill(isDrawn ? Color(.brandYellow).opacity(0.3) : .clear)
                .frame(width: 1.5)
        }
    }
}

//
//  RoutePlanCard+Rows.swift
//  Lezgo
//
//  Created by Farrell Sudjatmiko on 06/11/26.
//

import SwiftUI

extension RoutePlanCard {
    var stopsToggleRow: some View {
        let count = max(0, destinations.count - 1)

        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                isStopsExpanded.toggle()
            }
        } label: {
            VStack(spacing: 0) {
                HStack(alignment: .center, spacing: 12) {
                    ZStack {
                        Rectangle()
                            .fill(Color.heroYellow.opacity(0.85))
                            .frame(width: 1.5)

                        Image(systemName: "mappin.circle.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(Color.heroYellow)
                            .background(Color(red: 26 / 255, green: 26 / 255, blue: 28 / 255))
                            .frame(width: 24, height: 24)
                            .accessibilityHidden(true)
                    }
                    .frame(width: 24)

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
                .frame(minHeight: 36)

                Divider()
                    .overlay(Color(white: 0.22))
                    .padding(.leading, 36)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    func stopRow(index: Int, stop: RoutePoint) -> some View {
        let isFinalDestination = isStopsExpanded && index == destinations.count - 1

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
            if !isFinalDestination {
                Rectangle()
                    .fill(Color.heroYellow.opacity(0.85))
                    .frame(width: 1.5)
            } else {
                VStack(spacing: 0) {
                    Rectangle()
                        .fill(Color.heroYellow.opacity(0.85))
                        .frame(width: 1.5, height: 18)
                    Spacer(minLength: 0)
                }
            }

            Image(systemName: isFinalDestination ? "flag.checkered" : "mappin.circle.fill")
                .font(.system(size: 16))
                .foregroundStyle(Color.heroYellow)
                .background(Color(red: 26 / 255, green: 26 / 255, blue: 28 / 255))
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
                    .font(.system(size: 15))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(minHeight: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Image(systemName: "line.3.horizontal")
                .font(.system(size: 14))
                .foregroundStyle(Color(white: 0.35))
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
                .accessibilityLabel("Reorder")
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

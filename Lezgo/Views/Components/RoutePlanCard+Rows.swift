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
            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                isStopsExpanded.toggle()
            }
        } label: {
            HStack(alignment: .top, spacing: 12) {
                VStack(spacing: 0) {
                    Image(systemName: "mappin.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(Color.heroYellow)
                        .frame(width: 24, height: 24)
                        .accessibilityHidden(true)

                    Rectangle()
                        .fill(Color.heroYellow.opacity(0.85))
                        .frame(width: 1.5, height: 16)
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
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    func stopRow(index: Int, stop: RoutePoint) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 0) {
                Image(systemName: "mappin.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(Color.heroYellow)
                    .frame(width: 24, height: 24)
                    .accessibilityHidden(true)

                Rectangle()
                    .fill(Color.heroYellow.opacity(0.85))
                    .frame(width: 1.5, height: 16)
            }
            .frame(width: 24)

            if activeSelection == .destination(index: index) {
                searchTextField(placeholder: "Search stop")
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

                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 14))
                    .foregroundStyle(Color(white: 0.35))
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
                    .accessibilityLabel("Reorder")
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

    var addDestinationRow: some View {
        VStack(spacing: 12) {
            Divider()
                .overlay(Color(white: 0.22))

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

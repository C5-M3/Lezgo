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
            let isClosing = isStopsExpanded
            let animation = isClosing ? Self.closesStops : Self.opensStops
            // The list measures the new height only after laying the rows out, which would leave the card behind the
            // rows. The height is set here, in the same animation, and the measurement then only corrects it.
            let heightChange = CGFloat(count) * stopsToggleRowHeight
            withAnimation(animation.Respecting(reduceMotion: reduceMotion)) {
                isStopsExpanded.toggle()
                contentHeight += isClosing ? -heightChange : heightChange
            }
        } label: {
            VStack(spacing: 0) {
                HStack(alignment: .center, spacing: 12) {
                    ZStack {
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
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height in
            // The row's top and bottom list insets, 6 points each.
            stopsToggleRowHeight = height + 12
        }
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
            withAnimation(Self.closesStops.Respecting(reduceMotion: reduceMotion)) {
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
    /// The line joining the route's icons, drawn behind one row from the row's edge to its icon's centre. It is the
    /// row's background, which always fills the whole row, so the pieces of neighbouring rows meet in one unbroken
    /// line, as in the HiFi.
    struct ConnectorLine: View {
        let reachesUp: Bool
        let reachesDown: Bool
        /// The row's list insets: the icon sits in the middle of what is left, `leading` from the side.
        let insets: EdgeInsets
        /// Half of the icon column's width.
        private static let iconCentreOffset: CGFloat = 12

        var body: some View {
            GeometryReader { geometry in
                let height = geometry.size.height
                let centre = insets.top + (height - insets.top - insets.bottom) / 2
                let x = insets.leading + Self.iconCentreOffset
                Path { path in
                    if reachesUp {
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x, y: centre))
                    }
                    if reachesDown {
                        path.move(to: CGPoint(x: x, y: centre))
                        path.addLine(to: CGPoint(x: x, y: height))
                    }
                }
                .stroke(Color(.brandYellow).opacity(0.3), lineWidth: 1.5)
            }
            .accessibilityHidden(true)
        }
    }
}

/// A row that fades and slides down into place when it appears, a little later for each row below the first, so the
/// stops open one after another. Reduce Motion shows them at once.
struct StaggeredReveal: ViewModifier {
    let index: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isShown = false

    func body(content: Content) -> some View {
        content
            .opacity(isShown ? 1 : 0)
            .offset(y: isShown ? 0 : -10)
            .onAppear {
                let delay = 0.06 * Double(min(index, 6))
                withAnimation(RoutePlanCard.opensStops.delay(delay).Respecting(reduceMotion: reduceMotion)) {
                    isShown = true
                }
            }
    }
}

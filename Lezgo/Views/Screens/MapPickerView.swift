//
//  MapPickerView.swift
//  Lezgo
//

import MapKit
import SwiftUI

/// "Choose on Map": a map with a pin fixed at the center. The person moves the map under the pin, can snap to a
/// nearby place, and confirms. Set Route and Edit Route both open it from the search (decision record:
/// [0027](../../docs/adr/0027-ChooseOnMapWithNativeMapKit.md)).
struct MapPickerView: View {
    @Bindable var viewModel: MapPickerViewModel
    let onConfirm: () -> Void
    let onClose: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            map
            MapPickerPin(isLifted: viewModel.isMoving, street: viewModel.address?.street)
        }
        .overlay(alignment: .top) { topBar }
        // Above the card, level with the Apple Maps logo on the other side. The overlay sits inside the safe area
        // inset below, so the card never covers it.
        .overlay(alignment: .bottomTrailing) {
            Button("Current Location", systemImage: "location.fill", action: viewModel.MoveToUserLocation)
                .labelStyle(.iconOnly)
                .buttonStyle(RoundMapButtonStyle())
                .padding(.trailing, 16)
                .padding(.bottom, 8)
        }
        // The card is a safe area inset, so the map centers its camera above it, where the pin is drawn.
        .safeAreaInset(edge: .bottom, spacing: 0) {
            MapPickerCard(
                address: viewModel.address,
                isLoadingAddress: viewModel.isLoadingAddress,
                isMoving: viewModel.isMoving,
                nearbyPlaces: viewModel.nearbyPlaces,
                onSnap: Snap,
                onConfirm: onConfirm
            )
        }
        .sensoryFeedback(.impact(flexibility: .soft), trigger: viewModel.isMoving) { wasMoving, isMoving in
            wasMoving && !isMoving
        }
    }

    private var map: some View {
        Map(position: $viewModel.cameraPosition, interactionModes: [.pan, .zoom]) {
            UserAnnotation()
        }
        .mapStyle(.lezgo)
        .onMapCameraChange(frequency: .continuous) { _ in
            viewModel.CameraIsMoving()
        }
        .onMapCameraChange(frequency: .onEnd) { context in
            let center = context.camera.centerCoordinate
            viewModel.CameraMoved(to: Coordinate(latitude: center.latitude, longitude: center.longitude))
        }
    }

    private var topBar: some View {
        Button("Back", systemImage: "chevron.left", action: onClose)
            .labelStyle(.iconOnly)
            .buttonStyle(RoundMapButtonStyle())
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.top, 4)
    }

    private func Snap(to place: NearbyPlace) {
        withAnimation(Animation.lezgoPanel.Respecting(reduceMotion: reduceMotion)) {
            viewModel.Snap(to: place)
        }
    }
}

/// The pin in the middle of the map. Its tip is the chosen point; it lifts while the map moves.
private struct MapPickerPin: View {
    let isLifted: Bool
    let street: String?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// A map marker is a drawing, not text, so it keeps its size at every text size.
    private let pinHeight: CGFloat = 44

    var body: some View {
        ZStack {
            Ellipse()
                .fill(.black.opacity(0.4))
                .frame(width: isLifted ? 8 : 14, height: 5)

            PinIcon(height: pinHeight)
                .shadow(color: .black.opacity(0.35), radius: 3, y: 2)
                .offset(y: -pinHeight / 2 - (isLifted ? 10 : 0))
        }
        .animation(Animation.lezgoPress.Respecting(reduceMotion: reduceMotion), value: isLifted)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Selected location")
        .accessibilityValue(street ?? "")
        .allowsHitTesting(false)
    }
}

/// A dark round button for the two icons over the map, in the color of the card below. The icon is a map graphic, so
/// it stops growing before it would leave the circle.
private struct RoundMapButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.callout.weight(.bold))
            .dynamicTypeSize(...DynamicTypeSize.xxLarge)
            .foregroundStyle(.white)
            .frame(width: 40, height: 40)
            .background(Color(.tripCard), in: .circle)
            .contentShape(.circle)
            .pressFeedback(isPressed: configuration.isPressed)
    }
}

/// The yellow map pin with a black dot, drawn at any size: on the map and in the card.
private struct PinIcon: View {
    let height: CGFloat

    var body: some View {
        PinShape()
            .fill(Color(.brandYellow))
            .overlay(alignment: .top) {
                Circle()
                    .fill(.black)
                    .frame(width: height * 0.28, height: height * 0.28)
                    .padding(.top, height * 0.23)
            }
            .frame(width: height * 0.75, height: height)
    }
}

/// A round head that narrows to a tip at the bottom center, the map pin of the design.
private struct PinShape: Shape {
    func path(in rect: CGRect) -> Path {
        let radius = rect.width / 2
        var path = Path()
        path.addArc(
            center: CGPoint(x: rect.midX, y: rect.minY + radius),
            radius: radius,
            startAngle: .degrees(150),
            endAngle: .degrees(30),
            clockwise: false
        )
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

/// The bottom card: the address under the pin, places nearby, and the confirm button.
private struct MapPickerCard: View {
    let address: PlaceAddress?
    let isLoadingAddress: Bool
    let isMoving: Bool
    let nearbyPlaces: [NearbyPlace]
    let onSnap: (NearbyPlace) -> Void
    let onConfirm: () -> Void
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .body) private var pinHeight: CGFloat = 22
    /// The chips are in a scroll view that keeps its offset when the places change; a new list starts at the left.
    @State private var nearbyPosition = ScrollPosition(edge: .leading)

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            addressRow
            // At the largest text sizes the card keeps the address and the button; the chips would hide the map.
            if nearbyPlaces.isEmpty == false, dynamicTypeSize.isAccessibilitySize == false { nearbySection }
            Button("Confirm Location", action: onConfirm)
                .buttonStyle(.yellowCapsule(minHeight: 52))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
        .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Color(.tripCard)))
        .shadow(color: .black.opacity(0.3), radius: 14, x: 0, y: 6)
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    private var addressRow: some View {
        HStack(spacing: 12) {
            PinIcon(height: pinHeight)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                // Both lines are always drawn, blank when empty, so the row keeps one height. While the address loads
                // or is missing, the message sits in the middle of that height instead of on the first line.
                let shownAddress = isLoadingAddress ? nil : address
                let area = shownAddress?.area ?? ""
                Text(verbatim: shownAddress?.street ?? " ")
                    .font(.headline)
                    .foregroundStyle(.white)
                Text(verbatim: area.isEmpty ? " " : area)
                    .font(.caption)
                    .foregroundStyle(Color(white: 0.6))
                    .accessibilityHidden(area.isEmpty)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(alignment: .leading) {
                if address == nil || isLoadingAddress {
                    Text(isLoadingAddress ? "Looking for the address…" : "No address found here")
                        .font(.headline)
                        .foregroundStyle(Color(white: 0.6))
                }
            }
            .opacity(isMoving ? 0.45 : 1)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(white: 0.18), in: .rect(cornerRadius: 14))
        .accessibilityElement(children: .combine)
    }

    private var nearbySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Nearby")
                .font(.caption.weight(.semibold))
                .textCase(.uppercase)
                .foregroundStyle(Color(white: 0.6))

            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(nearbyPlaces) { place in
                        Button { onSnap(place) } label: {
                            Text(place.name)
                                .lineLimit(1)
                                .font(.subheadline)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 14)
                                .frame(minHeight: 44)
                                .background(Color(white: 0.18), in: .capsule)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .scrollIndicators(.hidden)
            .scrollPosition($nearbyPosition)
            .onChange(of: nearbyPlaces) {
                nearbyPosition.scrollTo(edge: .leading)
            }
        }
    }
}

#if DEBUG
#Preview {
    MapPickerView(
        viewModel: {
            let viewModel = MapPickerViewModel(
                selection: .destination(index: 0),
                startingAt: Coordinate(latitude: -7.2900, longitude: 112.7340),
                lookupService: InMemoryPlaceLookupService()
            )
            viewModel.Start()
            return viewModel
        }(),
        onConfirm: {},
        onClose: {}
    )
}
#endif

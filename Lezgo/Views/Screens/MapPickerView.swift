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
            MapPickerPin(isLifted: viewModel.isMoving, street: viewModel.shownName)
        }
        // Both cards are safe area insets, so the map centers its camera between them, where the pin is drawn, and
        // the pin stays in sight even when large text makes the cards tall.
        .safeAreaInset(edge: .top, spacing: 0) {
            VStack(spacing: 12) {
                header
                MapPickerAddressCard(
                    symbol: viewModel.pointSymbol,
                    name: viewModel.shownName,
                    isLoadingAddress: viewModel.isLoadingAddress,
                    isMoving: viewModel.isMoving
                )
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)
            .padding(.bottom, 8)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            MapPickerCard(nearbyPlaces: viewModel.nearbyPlaces, onSnap: Snap, onConfirm: onConfirm)
        }
        .sensoryFeedback(.impact(flexibility: .soft), trigger: viewModel.isMoving) { wasMoving, isMoving in
            wasMoving && !isMoving
        }
    }

    private var map: some View {
        Map(position: $viewModel.cameraPosition, interactionModes: [.pan, .zoom]) {
            UserAnnotation()
        }
        .mapStyle(.mapPicker)
        .onMapCameraChange(frequency: .continuous) { _ in
            viewModel.CameraIsMoving()
        }
        .onMapCameraChange(frequency: .onEnd) { context in
            let center = context.camera.centerCoordinate
            viewModel.CameraMoved(to: Coordinate(latitude: center.latitude, longitude: center.longitude))
        }
    }

    /// The back button and the title of the point being picked, like the Route Plan header.
    private var header: some View {
        HStack {
            Button("Back", systemImage: "chevron.left", action: onClose)
                .labelStyle(.iconOnly)
                .buttonStyle(RoundMapButtonStyle())

            Spacer()

            Text(viewModel.title)
                .font(.body.weight(.bold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .shadow(color: .black.opacity(0.6), radius: 4)
                .accessibilityAddTraits(.isHeader)

            Spacer()

            Color.clear
                .frame(width: 40, height: 40)
        }
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

/// A dark round button for the back icon over the map, in the color of the cards. The icon is a map graphic, so
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

/// The yellow map pin with a black dot, drawn at any size.
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

/// The card under the header: the icon of the point being picked and the name of the place under the pin.
private struct MapPickerAddressCard: View {
    let symbol: String
    let name: String?
    let isLoadingAddress: Bool
    let isMoving: Bool
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        HStack(spacing: 16) {
            // The icon is a map graphic, so it stops growing before it would run into the name.
            Image(systemName: symbol)
                .font(.callout)
                .dynamicTypeSize(...DynamicTypeSize.xxLarge)
                .foregroundStyle(Color(.brandYellow))
                .frame(width: 24)
                .accessibilityHidden(true)

            // The line is always drawn, blank when empty, so the card does not shrink while the address loads. While it
            // loads or is missing, the message takes its place.
            let shownName = isLoadingAddress ? nil : name
            Text(verbatim: shownName ?? " ")
                .font(.body)
                // Large text needs a third line for a long street; the card stays short enough to leave the pin in
                // sight.
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? 3 : 2)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
                .overlay(alignment: .leading) {
                    if shownName == nil {
                        Text(isLoadingAddress ? "Looking for the address…" : "No address found here")
                            .font(.body)
                            .foregroundStyle(Color(white: 0.6))
                    }
                }
                .opacity(isMoving ? 0.45 : 1)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
        .background(Color(.tripCard), in: .rect(cornerRadius: 20))
        .accessibilityElement(children: .combine)
    }
}

/// The bottom card: the question, places nearby, and the confirm button.
private struct MapPickerCard: View {
    let nearbyPlaces: [NearbyPlace]
    let onSnap: (NearbyPlace) -> Void
    let onConfirm: () -> Void
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    /// The chips are in a scroll view that keeps its offset when the places change; a new list starts at the left.
    @State private var nearbyPosition = ScrollPosition(edge: .leading)

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Is this the right spot?")
                .font(.title3.weight(.bold))
                .foregroundStyle(.white)
                .accessibilityAddTraits(.isHeader)
            // At the largest text sizes the card keeps the question and the button; the chips would hide the map.
            if nearbyPlaces.isEmpty == false, dynamicTypeSize.isAccessibilitySize == false { nearbySection }
            Button("Confirm", action: onConfirm)
                .buttonStyle(.yellowCapsule(minHeight: 52))
                .accessibilityLabel("Confirm Location")
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Color(.tripCard)))
        .shadow(color: .black.opacity(0.3), radius: 14, x: 0, y: 6)
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    private var nearbySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Other areas around here...")
                .font(.caption)
                .foregroundStyle(Color(white: 0.6))

            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(nearbyPlaces) { place in
                        Button { onSnap(place) } label: {
                            Text(place.name)
                                .lineLimit(1)
                                .font(.caption.weight(.semibold))
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

private extension MapStyle {
    /// The Lezgo map with points of interest, so the person can tell where the pin is. Only this screen shows them:
    /// it is used while planning, not while driving.
    static let mapPicker = MapStyle.standard(emphasis: .muted, pointsOfInterest: .all)
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

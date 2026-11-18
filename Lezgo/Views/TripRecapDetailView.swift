//
//  TripRecapDetailView.swift
//  Lezgo
//
//  Created by Rizal Pratama on 16/11/26.
//

import MapKit
import SwiftUI

/// Detail informasi riwayat trip recap yang diselesaikan.
/// Tampilannya mirip dengan `TripRoomView` dengan beberapa komponen interaktif
/// yang dihilangkan (tanpa Edit route, tanpa Add participant, tanpa Hold menu, tanpa Start Trip).
struct TripRecapDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .body) private var columnWidth: CGFloat = 96
    @State private var viewModel: TripRecapDetailViewModel
    @State private var isShareFailureShown = false

    private let mapHeight: CGFloat = 320

    @MainActor
    init(recap: TripRecap) {
        _viewModel = State(initialValue: TripRecapDetailViewModel(recap: recap))
    }

    @MainActor
    init(viewModel: TripRecapDetailViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                headerMapSection

                VStack(alignment: .leading, spacing: 28) {
                    overviewSection
                    participantsSection
                }
                .padding(.horizontal, 20)
            }
            .padding(.bottom, 48)
        }
        .scrollBounceBehavior(.basedOnSize)
        .scrollIndicators(.hidden)
        .ignoresSafeArea(edges: .top)
        .background(Color(LezgoSurface.page.color))
        .preferredColorScheme(.dark)
        .navigationBarBackButtonHidden(true)
        .toolbarVisibility(.hidden, for: .navigationBar)
        .overlay(alignment: .top) {
            topFloatingBar
        }
        .task {
            await viewModel.PrepareShareImage(using: TripRecapShareImage.Make)
        }
        .confirmDialog(
            isPresented: $isShareFailureShown,
            title: Text("Couldn't make the picture"),
            message: Text("Check your connection and try again."),
            cancelTitle: nil,
            confirmTitle: "OK",
            onConfirm: { }
        )
    }
}

// MARK: - Header & Map Section

private extension TripRecapDetailView {
    @ViewBuilder
    var headerMapSection: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 8) {
                mapView
                titleView
            }
        } else {
            mapView
                .overlay(alignment: .bottomLeading) {
                    titleView
                }
        }
    }

    @ViewBuilder
    var mapView: some View {
        Map(initialPosition: .rect(viewModel.boundingRect), interactionModes: []) {
            if viewModel.polyline.count > 1 {
                RouteLineMapContent(coordinates: viewModel.polyline.map(\.locationCoordinate))
            }

            Annotation("", coordinate: viewModel.startCoordinate.locationCoordinate) {
                Image(viewModel.leaderAvatar.topViewImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 44, height: 44)
                    .accessibilityHidden(true)
            }

            Annotation("", coordinate: viewModel.destinationCoordinate.locationCoordinate) {
                VStack(spacing: 2) {
                    RouteStopPin(kind: .destination)
                        .scaleEffect(0.75)

                    Text(viewModel.destinationName)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.85), radius: 3, x: 0, y: 1)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 130)
                }
            }
        }
        .mapStyle(.lezgo)
        .preferredColorScheme(.dark)
        .frame(height: mapHeight)
        .disabled(true)
        .allowsHitTesting(false)
        .overlay(alignment: .bottom) {
            LinearGradient(
                colors: [.clear, .black],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: mapHeight / 2)
            .allowsHitTesting(false)
        }
        .visualEffect { content, proxy in
            let pull = proxy.frame(in: .scrollView).minY
            return content.scaleEffect(1 + max(0, pull) / mapHeight, anchor: .bottom)
        }
    }

    @ViewBuilder
    var titleView: some View {
        Text(viewModel.title)
            .font(.system(size: 34, weight: .black))
            .foregroundStyle(.white)
            .padding(.horizontal, 20)
            .padding(.bottom, 4)
            .accessibilityAddTraits(.isHeader)
    }
}

// MARK: - Top Floating Bar

private extension TripRecapDetailView {
    @ViewBuilder
    var topFloatingBar: some View {
        HStack {
            backButton

            Spacer()

            shareButton
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    var backButton: some View {
        Button("Back", systemImage: "chevron.left") {
            hideKeyboard()
            dismiss()
        }
        .labelStyle(.iconOnly)
        .font(.callout.weight(.bold))
        .lezgoGlassButton(.round)
    }

    /// Shares the finished picture. Until it is ready the button makes it (again, after a failure), and the share
    /// sheet opens from the next tap.
    @ViewBuilder
    var shareButton: some View {
        if let shareImage = viewModel.shareImage {
            ShareLink(
                item: shareImage,
                preview: SharePreview(Text(viewModel.title), image: shareImage.previewImage)
            ) {
                shareIcon
            }
            .lezgoGlassButton(.round)
            .accessibilityLabel(Text("Share Trip Recap"))
        } else {
            Button {
                Task {
                    await viewModel.PrepareShareImage(using: TripRecapShareImage.Make)
                    isShareFailureShown = viewModel.isShareFailed
                }
            } label: {
                shareIcon
            }
            .disabled(viewModel.isPreparingShareImage)
            .lezgoGlassButton(.round)
            .accessibilityLabel(Text("Share Trip Recap"))
        }
    }

    var shareIcon: some View {
        Image(systemName: "square.and.arrow.up")
            .font(.callout.weight(.bold))
    }
}

// MARK: - Overview Section

private extension TripRecapDetailView {
    @ViewBuilder
    var overviewSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Overview")
                .font(.title2.weight(.bold))
                .foregroundStyle(.white)
                .accessibilityAddTraits(.isHeader)

            VStack(spacing: 20) {
                // Row 1: Starting Point, Destinations, Stops
                HStack(alignment: .top, spacing: 60) {
                    OverviewItem(
                        systemImage: "house.fill",
                        title: "Starting Point",
                        value: viewModel.startPointName
                    )

                    OverviewItem(
                        systemImage: "flag.pattern.checkered",
                        title: "Destinations",
                        value: viewModel.destinationName
                    )

                    OverviewItem(
                        systemImage: "mappin.circle.fill",
                        title: "Stops",
                        value: "\(viewModel.stopsCount)"
                    )
                }

                // Row 2: Time Spent, Total Distance, Empty 3rd column
                HStack(alignment: .top, spacing: 60) {
                    OverviewItem(
                        systemImage: "timer",
                        title: "Time Spent",
                        value: viewModel.timeSpentText
                    )

                    OverviewItem(
                        systemImage: "point.topleft.down.to.point.bottomright.curvepath",
                        title: "Total Distance",
                        value: viewModel.totalDistanceText
                    )

                    Color.clear
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }
}

// MARK: - Participants Section

private extension TripRecapDetailView {
    @ViewBuilder
    var participantsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Participants")
                .font(.title2.weight(.bold))
                .foregroundStyle(.white)
                .accessibilityAddTraits(.isHeader)
                .padding(.bottom, -10)
                .zIndex(1)

            if viewModel.participants.isEmpty {
                Text("No participants")
                    .font(.subheadline)
                    .foregroundStyle(Color(.tripCardSubtext))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 8)
            } else {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: columnWidth), spacing: 16, alignment: .top)],
                    spacing: 0
                ) {
                    ForEach(viewModel.participants) { participant in
                        ParticipantCell(participant: participant)
                    }
                }
            }
        }
    }
}

// MARK: - Subviews

private struct OverviewItem: View {
    let systemImage: String
    let title: LocalizedStringKey
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: systemImage)
                .font(.system(size: 22))
                .foregroundStyle(Color(.tripCardSubtext))
                .accessibilityHidden(true)

            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(Color(.tripCardSubtext))

            Text(value)
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

private struct ParticipantCell: View {
    let participant: TripRecapParticipant

    var body: some View {
        VStack(spacing: 4) {
            AvatarImage(avatar: participant.avatar, isSelected: false)
                .frame(width: AvatarImage.roomSize, height: AvatarImage.roomSize)
                .frame(minWidth: 0, maxWidth: .infinity)
                .padding(.bottom, -20)

            HStack(spacing: 4) {
                Text(participant.displayName)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                if participant.isLeader {
                    Image(systemName: "crown.fill")
                        .font(.caption)
                        .foregroundStyle(Color(.brandYellow))
                        .accessibilityHidden(true)
                }
            }

            if !participant.carDescription.isEmpty {
                Text(participant.carDescription)
                    .font(.subheadline)
                    .foregroundStyle(Color(.tripCardSubtext))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, -15)
        .accessibilityElement(children: .combine)
    }
}

#if DEBUG
#Preview {
    TripRecapDetailView(recap: .sample)
}
#endif

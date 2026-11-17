//
//  TripRecapView.swift
//  Lezgo
//
//  Created by Rizal Pratama on 16/11/26.
//

import MapKit
import SwiftUI

/// Tampilan daftar ringkasan riwayat perjalanan (Trip History / Recap).
struct TripRecapView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: TripRecapViewModel
    @State private var selectedRecap: TripRecap?
    @FocusState private var isSearchFocused: Bool

    @MainActor
    init(viewModel: TripRecapViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    @MainActor
    init() {
        _viewModel = State(initialValue: TripRecapViewModel())
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.tripCard)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    navigationHeader
                    scrollViewContent
                }

                searchBarOverlay
            }
            .navigationBarBackButtonHidden(true)
            .toolbarVisibility(.hidden, for: .navigationBar)
            .navigationDestination(item: $selectedRecap) { recap in
                TripRecapDetailView(recap: recap)
            }
        }
        .preferredColorScheme(.dark)
        .task {
            await viewModel.loadRecaps()
        }
        .onAppear {
            isSearchFocused = false
            hideKeyboard()
        }
        .onChange(of: selectedRecap) { _, newValue in
            if newValue != nil {
                isSearchFocused = false
                hideKeyboard()
            }
        }
    }
}

// MARK: - Header & Navigation

private extension TripRecapView {
    @ViewBuilder
    var navigationHeader: some View {
        HStack {
            backButton

            Spacer()

            Text("Trip History")
                .font(.title2.weight(.bold))
                .foregroundStyle(.white)

            Spacer()

            menuButton
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 20)
    }

    @ViewBuilder
    private var backButton: some View {
        if #available(iOS 18.0, *) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.title2)
                    .foregroundStyle(.white)
                    .frame(width: 25, height: 35)
            }
            .buttonStyle(.glass)
            .accessibilityLabel(Text("Back to Home"))
        } else {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.title2)
                    .foregroundStyle(.white)
                    .frame(width: 25, height: 35)
                    .background {
                        Circle()
                            .fill(.ultraThinMaterial)
                    }
            }
            .accessibilityLabel(Text("Back to Home"))
        }
    }

    @ViewBuilder
    private var menuButton: some View {
        Menu {
            sortOptions
        } label: {
            if #available(iOS 18.0, *) {
                Image(systemName: "line.3.horizontal.decrease")
                    .font(.title3)
                    .foregroundStyle(.white)
                    .frame(width: 25, height: 35)
            } else {
                Image(systemName: "line.3.horizontal.decrease")
                    .font(.title3)
                    .foregroundStyle(.white)
                    .frame(width: 25, height: 35)
                    .background {
                        Circle()
                            .fill(.ultraThinMaterial)
                    }
            }
        }
        .ifAvailableIOS18Glass()
        .accessibilityLabel(Text("Sort & Filter Options"))
    }

    private var sortOptions: some View {
        Group {
            Button("Newest First") {
                viewModel.sortOrder = .newest
            }
            Button("Oldest First") {
                viewModel.sortOrder = .oldest
            }
//            Button("Distance", systemImage: "location") {
//                viewModel.sortOrder = .distance
//            }
        }
    }
}

// MARK: - Scroll Content

private extension TripRecapView {
    @ViewBuilder
    var scrollViewContent: some View {
        ScrollView {
            if viewModel.isLoading && viewModel.recaps.isEmpty {
                loadingView
            } else if viewModel.errorMessage != nil && viewModel.recaps.isEmpty {
                errorView
            } else if viewModel.filteredRecaps.isEmpty {
                emptyStateView
            } else {
                cardsList
            }
        }
        .scrollDismissesKeyboard(.immediately)
        .scrollBounceBehavior(.basedOnSize)
        .refreshable {
            await viewModel.loadRecaps()
        }
    }

    @ViewBuilder
    var loadingView: some View {
        LazyVStack(spacing: 20) {
            ForEach(0..<3, id: \.self) { _ in
                TripRecapCardSkeleton()
                    .shimmer()
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 80)
    }

    @ViewBuilder
    var errorView: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundStyle(Color(.brandYellow))

            Text("Unable to Load Trips")
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)

            Text("Failed to retrieve trip history from iCloud.")
                .font(.subheadline)
                .foregroundStyle(Color(white: 0.5))
                .multilineTextAlignment(.center)

            Button("Retry") {
                Task {
                    await viewModel.loadRecaps()
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(Color(.brandYellow))
            .foregroundStyle(.black)
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
        .padding(.horizontal, 24)
    }

    @ViewBuilder
    var cardsList: some View {
        LazyVStack(spacing: 20) {
            ForEach(viewModel.filteredRecaps) { item in
                Button {
                    isSearchFocused = false
                    hideKeyboard()
                    selectedRecap = item
                } label: {
                    TripRecapCard(item: item)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 80)
    }

    @ViewBuilder
    var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 40))
                .foregroundStyle(Color(white: 0.5))

            if viewModel.searchQuery.isEmpty {
                Text("No Past Trips")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)

                Text("Completed trips will appear here.")
                    .font(.subheadline)
                    .foregroundStyle(Color(white: 0.5))
                    .multilineTextAlignment(.center)
            } else {
                Text("No Trips Found")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)

                Text("Try searching with a different destination name.")
                    .font(.subheadline)
                    .foregroundStyle(Color(white: 0.5))
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
        .padding(.horizontal, 24)
    }
}

// MARK: - Search Bar

private extension TripRecapView {
    @ViewBuilder
    var searchBarOverlay: some View {
        VStack {
            Spacer()

            if #available(iOS 18.0, *) {
                searchBarContent
                    .glassEffect(.regular.interactive(), in: Capsule())
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)
            } else {
                searchBarContent
                    .background {
                        RoundedRectangle(cornerRadius: 26, style: .continuous)
                            .fill(Color(red: 20/255, green: 35/255, blue: 40/255).opacity(0.85))
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 26, style: .continuous)
                                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
                            }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)
            }
        }
    }

    @ViewBuilder
    private var searchBarContent: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.body.weight(.semibold))

            TextField("Search", text: $viewModel.searchQuery)
                .focused($isSearchFocused)
                .foregroundStyle(.white)
                .font(.body.weight(.semibold))
                .autocorrectionDisabled()

            if !viewModel.searchQuery.isEmpty {
                Button {
                    viewModel.searchQuery = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Color(white: 0.6))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

// MARK: - Trip Recap Card

private struct TripRecapCard: View {
    let item: TripRecap

    /// The avatar asset has transparent margins: ~29.4% horizontal (603/2048 px) and ~28.6% vertical (585/2048 px).
    /// Negative padding aligns the visible robot avatar leading edge with the text above and removes excessive vertical space.
    private static let avatarLeadingOffset: CGFloat = 50 * (603.0 / 2048.0)
    private static let avatarVerticalOffset: CGFloat = 50 * (585.0 / 2048.0)

    /// Menghasilkan avatar yang dinamis mengikuti data dari `item.dynamicAvatars`.
    private var displayedAvatars: [Avatar] {
        Array(item.dynamicAvatars.prefix(4))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            mapSection
            infoSection
        }
        .background(Color(red: 28/255, green: 28/255, blue: 30/255))
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    @ViewBuilder
    private var mapSection: some View {
        Map(initialPosition: .rect(item.boundingRect), interactionModes: []) {
            RouteLineMapContent(coordinates: item.polyline.map(\.locationCoordinate))

            if let start = item.polyline.first {
                Annotation("", coordinate: start.locationCoordinate) {
                    Image(displayedAvatars.first?.topViewImage ?? .ontripNoglowYellow)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 40, height: 40)
                        .accessibilityHidden(true)
                }
            }

            if let destination = item.polyline.last {
                Annotation("", coordinate: destination.locationCoordinate) {
                    VStack(spacing: 2) {
                        RouteStopPin(kind: .destination)
                            .scaleEffect(0.75)

                        Text(item.destinationLabel)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.85), radius: 3, x: 0, y: 1)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 130)
                    }
                }
            }
        }
        .mapStyle(.lezgo)
        .preferredColorScheme(.dark)
        .frame(height: 180)
        .disabled(true)
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.destinationName)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)

                Text(item.formattedDate)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color(white: 0.4))
            }

            HStack(spacing: 0) {
                if !displayedAvatars.isEmpty {
                    HStack(spacing: -22) {
                        ForEach(Array(displayedAvatars.enumerated()), id: \.offset) { index, avatar in
                            Image(avatar.frontImage)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 50, height: 50)
                                .zIndex(Double(displayedAvatars.count - index))
                        }
                    }
                    .padding(.leading, -Self.avatarLeadingOffset)
                    .padding(.vertical, -Self.avatarVerticalOffset)
                }

                Text("\(item.participantCount) people · \(item.distanceText)")
                    .font(.subheadline)
                    .foregroundStyle(Color(white: 0.6))
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Skeleton & Shimmer

private struct TripRecapCardSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Map placeholder
            Rectangle()
                .fill(Color(white: 0.16))
                .frame(height: 180)

            // Info placeholder
            VStack(alignment: .leading, spacing: 12) {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color(white: 0.22))
                    .frame(width: 180, height: 20)

                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(Color(white: 0.18))
                    .frame(width: 120, height: 14)

                HStack(spacing: 8) {
                    HStack(spacing: -10) {
                        ForEach(0..<3, id: \.self) { _ in
                            Circle()
                                .fill(Color(white: 0.24))
                                .frame(width: 30, height: 30)
                        }
                    }

                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(Color(white: 0.18))
                        .frame(width: 130, height: 14)
                }
                .padding(.top, 4)
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color(red: 28/255, green: 28/255, blue: 30/255))
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
    }
}

private struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = -1.0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        if reduceMotion {
            content
        } else {
            content
                .overlay {
                    GeometryReader { proxy in
                        let width = proxy.size.width
                        LinearGradient(
                            stops: [
                                .init(color: .clear, location: 0.0),
                                .init(color: Color.white.opacity(0.15), location: 0.5),
                                .init(color: .clear, location: 1.0)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: width * 1.5)
                        .offset(x: phase * width * 1.5)
                    }
                    .mask(content)
                    .allowsHitTesting(false)
                }
                .onAppear {
                    withAnimation(
                        .linear(duration: 1.5)
                        .repeatForever(autoreverses: false)
                    ) {
                        phase = 1.0
                    }
                }
        }
    }
}

private extension View {
    func shimmer() -> some View {
        modifier(ShimmerModifier())
    }
}

// MARK: - View Modifiers

private extension View {
    @ViewBuilder
    func ifAvailableIOS18Glass() -> some View {
        if #available(iOS 18.0, *) {
            self.buttonStyle(.glass)
        } else {
            self
        }
    }
}

#Preview {
    TripRecapView(viewModel: TripRecapViewModel(storage: UserDefaultsTripRecapStorage()))
}

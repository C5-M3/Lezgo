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

    private var backButton: some View {
        Button("Back to Home", systemImage: "chevron.left") { dismiss() }
            .labelStyle(.iconOnly)
            .font(.callout.weight(.bold))
            .lezgoGlassButton(.round)
    }

    private var menuButton: some View {
        Menu {
            sortOptions
        } label: {
            Image(systemName: "line.3.horizontal.decrease")
                .font(.callout.weight(.bold))
        }
        .lezgoGlassButton(.round)
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
                .accessibilityHidden(true)

            Text("Unable to Load Trips")
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)

            Text("Failed to retrieve trip history from iCloud.")
                .font(.subheadline)
                .foregroundStyle(Color(.tripCardSubtext))
                .multilineTextAlignment(.center)

            Button("Retry") {
                Task {
                    await viewModel.loadRecaps()
                }
            }
            .lezgoGlassButton(.main)
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
                .foregroundStyle(Color(.tripCardSubtext))
                .accessibilityHidden(true)

            if viewModel.searchQuery.isEmpty {
                Text("No Past Trips")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)

                Text("Completed trips will appear here.")
                    .font(.subheadline)
                    .foregroundStyle(Color(.tripCardSubtext))
                    .multilineTextAlignment(.center)
            } else {
                Text("No Trips Found")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)

                Text("Try searching with a different destination name.")
                    .font(.subheadline)
                    .foregroundStyle(Color(.tripCardSubtext))
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

            searchBarContent
                .glassEffect(.regular.interactive(), in: Capsule())
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
        }
    }

    @ViewBuilder
    private var searchBarContent: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.body.weight(.semibold))
                .accessibilityHidden(true)

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
                        .foregroundStyle(Color(.tripCardSubtext))
                        .accessibilityHidden(true)
                }
                .accessibilityLabel(Text("Clear search text"))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

#Preview {
    TripRecapView(viewModel: TripRecapViewModel(storage: UserDefaultsTripRecapStorage()))
}

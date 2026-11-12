//
//  SetRouteView.swift
//  Lezgo
//
//  Created by Farrell Sudjatmiko on 05/11/26.
//

import MapKit
import SwiftUI

struct SetRouteView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.tripService) var tripService
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @State var viewModel: MapViewModel
    @State var isShowingBackConfirmation: Bool = false
    @State var activeMapSession: TripSession?
    @State var isStopsExpanded: Bool = false
    /// Where the map sits on screen, so the cards' frames can be turned into map insets.
    @State var mapFrame: CGRect = .zero
    /// The bottom edge of the back button and route card, measured on every layout.
    @State var routeControlsBottom: CGFloat = 0
    /// The bottom edge of the route card while it shows its collapsed rows. The route is framed below this, so
    /// opening the stop list or the search does not move the map.
    @State var collapsedRouteControlsBottom: CGFloat = 0
    /// The top edge of the metrics card.
    @State var metricsCardTop: CGFloat = 0

    let title: LocalizedStringResource
    let saveTitle: LocalizedStringResource
    let onBack: (() -> Void)?
    let onNext: (() -> Void)?
    let onTripCreated: ((TripSession) -> Void)?
    let onDismiss: (() -> Void)?
    let isBackDisabled: Bool
    let isNextDisabled: Bool
    /// `true` while a caller saves the route itself, like Edit Route; Save shows progress meanwhile.
    let isSaving: Bool
    let isStartPointLocked: Bool

    init(
        viewModel: MapViewModel = MapViewModel(),
        title: LocalizedStringResource = "Plan the route",
        saveTitle: LocalizedStringResource = "Save",
        onBack: (() -> Void)? = nil,
        onNext: (() -> Void)? = nil,
        onTripCreated: ((TripSession) -> Void)? = nil,
        onDismiss: (() -> Void)? = nil,
        isBackDisabled: Bool = false,
        isNextDisabled: Bool = false,
        isSaving: Bool = false,
        isStartPointLocked: Bool = false
    ) {
        _viewModel = State(initialValue: viewModel)
        self.title = title
        self.saveTitle = saveTitle
        self.onBack = onBack
        self.onNext = onNext
        self.onTripCreated = onTripCreated
        self.onDismiss = onDismiss
        self.isBackDisabled = isBackDisabled
        self.isNextDisabled = isNextDisabled
        self.isSaving = isSaving
        self.isStartPointLocked = isStartPointLocked
    }

    var body: some View {
        ZStack {
            mapSection
                .ignoresSafeArea()

            if viewModel.isSearching {
                Color.black.opacity(0.88)
                    .ignoresSafeArea()
                    .transition(.opacity)
            } else {
                mapVignetteOverlay
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }

            VStack(spacing: 12) {
                VStack(spacing: 12) {
                    topNavigationBar

                    routePlanCardView
                }
                .fullScreenCover(isPresented: isShowingMapPicker) {
                    if let picker = viewModel.mapPicker {
                        MapPickerView(
                            viewModel: picker,
                            onConfirm: viewModel.ConfirmMapPick,
                            onClose: viewModel.CancelMapPick
                        )
                    }
                }
                .onGeometryChange(for: CGFloat.self) { proxy in
                    proxy.frame(in: .global).maxY
                } action: { bottom in
                    routeControlsBottom = bottom
                    RememberCollapsedRouteControls()
                }

                if viewModel.isSearching {
                    suggestionsListView
                } else {
                    Spacer()

                    if isShowingMetricsCard {
                        metricsBottomCardView
                            .onGeometryChange(for: CGFloat.self) { proxy in
                                proxy.frame(in: .global).minY
                            } action: { top in
                                metricsCardTop = top
                            }
                    }
                }
            }
        }
        // The card keeps its height when the search opens or closes, so no new measurement may follow.
        .onChange(of: viewModel.isSearching) { RememberCollapsedRouteControls() }
        .onChange(of: isStopsExpanded) { RememberCollapsedRouteControls() }
        .confirmDialog(
            isPresented: $isShowingBackConfirmation,
            title: Text("Discard Changes?"),
            message: Text("Going back will clear your selected destination and route planning"),
            cancelTitle: "Cancel",
            confirmTitle: "Discard",
            isDestructive: true,
            onConfirm: HandleBack
        )
        .confirmDialog(
            isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            ),
            title: Text("Notice"),
            message: Text(verbatim: viewModel.errorMessage ?? ""),
            cancelTitle: nil,
            confirmTitle: "OK",
            onConfirm: { }
        )
        .fullScreenCover(
            item: $viewModel.createdSession,
            onDismiss: HandleTripRoomDismissed,
            content: { session in
                tripRoomCover(session: session)
            }
        )
        .onAppear {
            viewModel.onAppear()
        }
    }
}

// MARK: - Subviews

private extension SetRouteView {
    /// The map picker opens over the search; closing it any way, even by swiping, leaves the route as it was.
    var isShowingMapPicker: Binding<Bool> {
        Binding(
            get: { viewModel.mapPicker != nil },
            set: { if !$0 { viewModel.CancelMapPick() } }
        )
    }

    var topNavigationBar: some View {
        HStack {
            Button(action: HandleBackButtonTapped) {
                Circle()
                    .fill(Color(white: 0.16).opacity(0.92))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Image(systemName: "chevron.left")
                            .font(.callout.weight(.bold))
                            .foregroundStyle(.white)
                            .accessibilityHidden(true)
                    )
            }
            .buttonStyle(.plain)
            .disabled(isBackDisabled)
            .accessibilityLabel("Back")

            Spacer()

            Text(navigationTitleText)
                .font(.body.weight(.bold))
                .foregroundStyle(.white)

            Spacer()

            Color.clear
                .frame(width: 40, height: 40)
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
    }

    var navigationTitleText: LocalizedStringResource {
        if viewModel.isSearching {
            return "Route Plan"
        } else {
            return title
        }
    }

    var routePlanCardView: some View {
        @Bindable var boundViewModel = viewModel
        return RoutePlanCard(
            startPoint: viewModel.startPoint,
            destinations: viewModel.destinations,
            activeSelection: viewModel.activeSelectionSheet,
            searchQuery: $boundViewModel.searchQuery,
            isStartPointLocked: isStartPointLocked,
            isStopsExpanded: $isStopsExpanded,
            onSelectPointForEditing: { selection in
                viewModel.activeSelectionSheet = selection
                if case .destination(let index) = selection, index < viewModel.destinations.count {
                    viewModel.searchQuery = viewModel.destinations[index].name
                    viewModel.onSearchQueryChanged(viewModel.searchQuery)
                } else if selection == .start, let start = viewModel.startPoint,
                          start.name != String(localized: .waypointCurrentLocation) {
                    viewModel.searchQuery = start.name
                    viewModel.onSearchQueryChanged(viewModel.searchQuery)
                } else {
                    viewModel.searchQuery = ""
                    viewModel.onSearchQueryChanged("")
                }
            },
            onClearSearch: {
                viewModel.searchQuery = ""
                viewModel.searchService.updateQueryFragment("")
            },
            onAddDestination: {
                viewModel.addDestination()
            },
            onRemoveDestination: { index in
                viewModel.removeDestination(at: index)
            },
            onMoveDestination: { fromOffsets, toOffset in
                viewModel.moveDestination(fromOffsets: fromOffsets, toOffset: toOffset)
            }
        )
        .onChange(of: viewModel.searchQuery) { _, newValue in
            if viewModel.isSearching {
                viewModel.onSearchQueryChanged(newValue)
            }
        }
    }

    var suggestionsListView: some View {
        RouteSearchSuggestionsList(
            searchResults: viewModel.searchService.searchResults,
            isSearching: viewModel.searchService.isSearching,
            searchQuery: viewModel.searchQuery,
            selectionType: viewModel.activeSelectionSheet,
            userLocation: viewModel.locationService.userLocation,
            onSelectCurrentLocation: {
                viewModel.selectCurrentLocationAsStart()
            },
            onChooseOnMap: {
                viewModel.StartPickingOnMap()
            },
            onSelectResult: { result in
                viewModel.selectSearchResult(result)
            }
        )
        .transition(.opacity)
    }

    var metricsBottomCardView: some View {
        RouteMetricsBottomCard(
            duration: viewModel.totalDuration,
            distance: viewModel.totalDistance,
            destinationCount: viewModel.destinations.count,
            hasIntermediateStops: viewModel.destinations.count > 1,
            isLoadingRoute: viewModel.isLoadingRoute,
            canSave: canSaveRoute,
            isSaving: isShowingSaveProgress,
            saveTitle: saveTitle,
            onSave: HandleSave
        )
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    var canSaveRoute: Bool {
        if isNextDisabled { return false }
        if onNext != nil { return viewModel.MakeTripPlan() != nil }
        return viewModel.canCreateTrip
    }
}

// MARK: - Actions & Navigation

extension SetRouteView {
    /// Creating a trip saves in the planner; Edit Route saves in its own view model.
    var isShowingSaveProgress: Bool {
        viewModel.isCreatingTrip || isSaving
    }

    func HandleBackButtonTapped() {
        if viewModel.isSearching {
            if !viewModel.destinations.isEmpty {
                withAnimation(Animation.lezgoSwap.Respecting(reduceMotion: reduceMotion)) {
                    viewModel.closeSearch()
                }
                return
            }
        }

        if viewModel.hasPlanChanges {
            isShowingBackConfirmation = true
        } else {
            HandleBack()
        }
    }

    func HandleBack() {
        viewModel.clearDestinationSearch()
        if let onBack {
            onBack()
        } else if let onDismiss {
            onDismiss()
        } else {
            dismiss()
        }
    }

    func HandleSave() {
        if let onNext {
            onNext()
        } else {
            Task {
                do {
                    let session = try await viewModel.CreateTrip(using: tripService)
                    if let onTripCreated {
                        viewModel.createdSession = nil
                        onTripCreated(session)
                    }
                } catch {
                    // Handled via viewModel.errorMessage alert
                }
            }
        }
    }

    func HandleTripRoomDismissed() {
        viewModel.createdSession = nil
        HandleBack()
    }
}

#Preview("Route Plan") {
    SetRouteView()
}

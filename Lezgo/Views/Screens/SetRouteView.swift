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
    @State var viewModel: MapViewModel
    @State var isShowingBackConfirmation: Bool = false
    @State var activeMapSession: TripSession?
    @State var isStopsExpanded: Bool = false

    let title: LocalizedStringResource
    let saveTitle: LocalizedStringResource
    let onBack: (() -> Void)?
    let onNext: (() -> Void)?
    let onTripCreated: ((TripSession) -> Void)?
    let onDismiss: (() -> Void)?
    let isBackDisabled: Bool
    let isNextDisabled: Bool
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
                topNavigationBar

                routePlanCardView

                if viewModel.isSearching {
                    suggestionsListView
                } else {
                    Spacer()

                    if viewModel.hasRoute || viewModel.isLoadingRoute {
                        metricsBottomCardView
                    }
                }
            }
        }
        .alert(
            "Discard Changes?",
            isPresented: $isShowingBackConfirmation
        ) {
            Button("Cancel", role: .cancel) { }
            Button("Discard", role: .destructive) {
                HandleBack()
            }
        } message: {
            Text("Going back will clear your selected destination and route planning")
        }
        .alert(
            "Notice",
            isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )
        ) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
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
    var topNavigationBar: some View {
        HStack {
            Button(action: HandleBackButtonTapped) {
                Circle()
                    .fill(Color(white: 0.16).opacity(0.92))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                            .accessibilityHidden(true)
                    )
            }
            .buttonStyle(.plain)
            .disabled(isBackDisabled)
            .accessibilityLabel("Back")

            Spacer()

            Text(navigationTitleText)
                .font(.system(size: 18, weight: .bold))
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
            isSaving: viewModel.isCreatingTrip,
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

// MARK: - Map

private extension SetRouteView {
    var mapVignetteOverlay: some View {
        VStack(spacing: 0) {
            LinearGradient(
                colors: [
                    Color.black.opacity(0.85),
                    Color.black.opacity(0.4),
                    Color.clear
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 200)

            Spacer()

            LinearGradient(
                colors: [
                    Color.clear,
                    Color.black.opacity(0.45),
                    Color.black.opacity(0.9)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 240)
        }
    }

    @ViewBuilder
    var mapSection: some View {
        @Bindable var boundViewModel = viewModel
        MapReader { proxy in
            Map(
                position: $boundViewModel.cameraPosition,
                interactionModes: [.pan, .zoom]
            ) {
                UserAnnotation()

                if let start = viewModel.startPoint, start.name != String(localized: .waypointCurrentLocation) {
                    Marker(start.name, coordinate: start.coordinate)
                        .tint(.blue)
                }

                ForEach(Array(viewModel.destinations.enumerated()), id: \.element.id) { index, point in
                    if viewModel.destinations.count == 1 || index == viewModel.destinations.count - 1 {
                        Marker(point.name, coordinate: point.coordinate)
                            .tint(.red)
                    } else {
                        Marker(
                            "\(index + 1). \(point.name)",
                            systemImage: "\(index + 1).circle",
                            coordinate: point.coordinate
                        )
                        .tint(.purple)
                    }
                }

                ForEach(viewModel.routeLegs) { leg in
                    ForEach(Array(leg.routes.enumerated()), id: \.offset) { routeIndex, route in
                        if routeIndex != leg.selectedRouteIndex {
                            MapPolyline(route.polyline)
                                .stroke(Color.heroYellow.opacity(0.38), lineWidth: 5)
                        }
                    }
                }

                ForEach(viewModel.selectedPolylines, id: \.self) { polyline in
                    MapPolyline(polyline)
                        .stroke(Color.heroYellow, lineWidth: 6)
                }
            }
            .onTapGesture { screenPoint in
                if let coord = proxy.convert(screenPoint, from: .local) {
                    viewModel.selectNearestRoute(to: coord, drawerHeight: 180)
                }
            }
            .accessibilityAddTraits(.isButton)
            .mapControls { }
            .safeAreaPadding(.bottom, (viewModel.hasRoute || viewModel.isLoadingRoute) ? 170 : 30)
        }
    }
}

// MARK: - Actions & Navigation

extension SetRouteView {
    func HandleBackButtonTapped() {
        if viewModel.isSearching {
            if !viewModel.destinations.isEmpty {
                withAnimation {
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

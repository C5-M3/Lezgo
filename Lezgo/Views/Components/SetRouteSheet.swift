//
//  SetRouteSheet.swift
//  Lezgo
//
//  Created by Farrell Sudjatmiko on 26/10/26.
//

import MapKit
import SwiftUI

struct SetRouteSheet: View {
    @Environment(\.tripService) private var tripService
    @Bindable var viewModel: MapViewModel
    var isFullPresentation: Bool = false
    /// "Set Route" when planning a trip, "Edit Route" on the road.
    var title: LocalizedStringResource = "Set Route"
    var nextTitle: LocalizedStringResource = "Next"
    /// Set by the screen that shows the planner, so Draft Trip and Edit Route each decide where Back and Next go.
    var onBack: (() -> Void)?
    var onNext: (() -> Void)?
    var onTripCreated: ((TripSession) -> Void)?
    var onExpand: (() -> Void)?
    var isBackDisabled = false
    var isNextDisabled = false
    /// Edit Route always starts from the leader's position, so there the start point cannot be changed.
    var isStartPointLocked = false
    @State private var isShowingBackConfirmation: Bool = false
    @State private var activeMapSession: TripSession?

    private var isNextButtonDisabled: Bool {
        if isNextDisabled { return true }
        if onNext != nil { return false }
        return !viewModel.canCreateTrip
    }

    var body: some View {
        NavigationStack {
            Form {
                startingPointSection
                destinationsSection

                // Section 3: Summary Metrics (shown only when pulled to full)
                if isFullPresentation {
                    TripSummarySection(
                        isLoadingRoute: viewModel.isLoadingRoute,
                        hasRoute: viewModel.hasRoute,
                        totalDistance: viewModel.totalDistance,
                        totalDuration: viewModel.totalDuration
                    )
                }
            }
            .navigationTitle(Text(title))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                toolbarLeading
                toolbarTrailing
            }
            .alert(
                "Discard Changes?",
                isPresented: $isShowingBackConfirmation
            ) {
                Button("Cancel", role: .cancel) { }
                Button("Discard", role: .destructive) {
                    onBack?()
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
        }
    }
}

// MARK: - Subviews & Actions

private extension SetRouteSheet {
    @ToolbarContentBuilder
    var toolbarLeading: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button("Back", systemImage: "chevron.left") {
                if viewModel.hasPlanChanges {
                    isShowingBackConfirmation = true
                } else {
                    onBack?()
                }
            }
            .disabled(isBackDisabled)
        }
    }

    @ToolbarContentBuilder
    var toolbarTrailing: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            if viewModel.isCreatingTrip {
                ProgressView()
            } else {
                Button(nextTitle, systemImage: "arrow.right", action: HandleNext)
                    .disabled(isNextButtonDisabled)
            }
        }
    }

    @ViewBuilder
    var startingPointSection: some View {
        Section("Starting Point") {
            Button {
                viewModel.activeSelectionSheet = .start
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "location.fill")
                        .accessibilityHidden(true)
                        .foregroundStyle(.secondary)
                    Text(viewModel.startPoint?.name ?? "Choose Starting Point...")
                        .font(.body)
                        .foregroundStyle(viewModel.startPoint == nil ? .secondary : .primary)
                        .lineLimit(1)
                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(isStartPointLocked)
        }
    }

    @ViewBuilder
    var destinationsSection: some View {
        Section("Destinations") {
            if !isFullPresentation && viewModel.destinations.count > 2 {
                collapsedDestinationsView
            } else {
                fullDestinationsView
            }
        }
    }

    @ViewBuilder
    var collapsedDestinationsView: some View {
        let intermediateCount = viewModel.destinations.count - 1
        Button {
            onExpand?()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "ellipsis.circle")
                    .accessibilityHidden(true)
                    .foregroundStyle(.secondary)

                Text(intermediateCount == 1 ? "1 stop" : "\(intermediateCount) stops")
                    .font(.body)
                    .foregroundStyle(.secondary)

                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)

        if let lastDestination = viewModel.destinations.last,
           let lastIndex = viewModel.destinations.indices.last {
            Button {
                viewModel.activeSelectionSheet = .destination(index: lastIndex)
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "mappin")
                        .accessibilityHidden(true)
                        .foregroundStyle(.secondary)

                    Text(lastDestination.name)
                        .font(.body)
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                Button(role: .destructive) {
                    viewModel.removeDestination(at: lastIndex)
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
    }

    @ViewBuilder
    var fullDestinationsView: some View {
        ForEach(Array(viewModel.destinations.enumerated()), id: \.element.id) { index, point in
            destinationRow(index: index, point: point)
        }
        .onDelete { indexSet in
            for index in indexSet.sorted().reversed() {
                viewModel.removeDestination(at: index)
            }
        }
        .onMove { fromOffsets, toOffset in
            if isFullPresentation {
                viewModel.moveDestination(fromOffsets: fromOffsets, toOffset: toOffset)
            }
        }

        if isFullPresentation || viewModel.destinations.count <= 1 {
            Button {
                viewModel.addDestination()
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "plus")
                        .accessibilityHidden(true)
                        .foregroundStyle(.secondary)
                    Text("Add...")
                        .font(.body)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    func destinationRow(index: Int, point: RoutePoint) -> some View {
        HStack(spacing: 12) {
            Button {
                viewModel.activeSelectionSheet = .destination(index: index)
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "mappin")
                        .accessibilityHidden(true)
                        .foregroundStyle(.secondary)

                    Text(point.name)
                        .font(.body)
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isFullPresentation && viewModel.destinations.count > 1 {
                Image(systemName: "line.3.horizontal")
                    .accessibilityHidden(true)
                    .foregroundStyle(.tertiary)
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                viewModel.removeDestination(at: index)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .draggable(point.id.uuidString)
        .dropDestination(for: String.self) { items, _ in
            guard let draggedID = items.first,
                  let fromIndex = viewModel.destinations.firstIndex(where: {
                      $0.id.uuidString == draggedID
                  }),
                  fromIndex != index else {
                return false
            }
            withAnimation {
                viewModel.moveDestination(
                    fromOffsets: IndexSet(integer: fromIndex),
                    toOffset: index > fromIndex ? index + 1 : index
                )
            }
            return true
        }
    }

    @ViewBuilder
    func tripRoomCover(session: TripSession) -> some View {
        TripRoomView(
            viewModel: TripRoomViewModel(
                tripService: tripService,
                tripID: session.state.trip.id,
                myParticipantID: session.myParticipantID,
                initialState: session.state,
                activeTripStorage: viewModel.activeTripStorage
            ),
            onTripStarted: {
                activeMapSession = session
            }
        )
        .fullScreenCover(
            item: $activeMapSession,
            onDismiss: {
                viewModel.activeTripStorage.ClearActiveTrip()
                activeMapSession = nil
                HandleTripRoomDismissed()
            },
            content: { mapSession in
                tripMapCover(mapSession: mapSession)
            }
        )
    }

    @ViewBuilder
    func tripMapCover(mapSession: TripSession) -> some View {
        TripMapView(
            viewModel: TripMapViewModel(
                session: mapSession,
                tripService: tripService,
                activeTripStorage: viewModel.activeTripStorage
            ),
            onNewDestination: {},
            onClose: {
                viewModel.activeTripStorage.ClearActiveTrip()
                activeMapSession = nil
                HandleTripRoomDismissed()
            }
        )
    }

    func HandleNext() {
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
                    // Error message is set in viewModel.errorMessage and shown in alert
                }
            }
        }
    }

    func HandleTripRoomDismissed() {
        viewModel.createdSession = nil
        onBack?()
    }
}

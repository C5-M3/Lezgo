//
//  SetRouteSheet.swift
//  Lezgo
//
//  Created by Farrell Sudjatmiko on 26/10/26.
//

import SwiftUI
import MapKit

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
    var isBackDisabled = false
    var isNextDisabled = false
    /// Edit Route always starts from the leader's position, so there the start point cannot be changed.
    var isStartPointLocked = false
    @State private var isShowingBackConfirmation: Bool = false

    private var isNextButtonDisabled: Bool {
        if isNextDisabled { return true }
        if onNext != nil { return false }
        return !viewModel.canCreateTrip
    }

    var body: some View {
        NavigationStack {
            Form {
                // Section 1: Starting Point
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

                // Section 2: Destinations (unified hierarchy)
                Section("Destinations") {
                    if !isFullPresentation && viewModel.destinations.count > 2 {
                        // Collapsed: Top row shows summary count of previous stops
                        let intermediateCount = viewModel.destinations.count - 1
                        HStack(spacing: 12) {
                            Image(systemName: "ellipsis.circle")
                                .accessibilityHidden(true)
                                .foregroundStyle(.secondary)

                            Text(intermediateCount == 1 ? "1 stop" : "\(intermediateCount) stops")
                                .font(.body)
                                .foregroundStyle(.secondary)

                            Spacer()
                        }

                        // Collapsed: Bottom row shows the final destination
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
                    } else {
                        // Full presentation OR 2 or fewer destinations: show all items
                        ForEach(Array(viewModel.destinations.enumerated()), id: \.element.id) { index, point in
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
                }

                // Section 3: Summary Metrics (shown only when pulled to full)
                if isFullPresentation {
                    if viewModel.isLoadingRoute {
                        HStack {
                            Spacer()
                            ProgressView("Calculating optimal route...")
                            Spacer()
                        }
                    } else if viewModel.hasRoute {
                        Section("Trip Summary") {
                            let distFormatted = String(format: "%.1f km", viewModel.totalDistance / 1000)
                            LabeledContent("Total Distance", value: distFormatted)
                            LabeledContent("Estimated Time", value: "\(Int(viewModel.totalDuration / 60)) min")
                        }
                    }
                }
            }
            .navigationTitle(Text(title))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
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
                ToolbarItem(placement: .topBarTrailing) {
                    if viewModel.isCreatingTrip {
                        ProgressView()
                    } else {
                        Button(nextTitle, systemImage: "arrow.right", action: HandleNext)
                            .disabled(isNextButtonDisabled)
                    }
                }
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
            .fullScreenCover(item: $viewModel.createdSession, onDismiss: HandleTripRoomDismissed) { session in
                TripRoomView(
                    viewModel: TripRoomViewModel(
                        tripService: tripService,
                        tripID: session.state.trip.id,
                        myParticipantID: session.myParticipantID,
                        initialState: session.state
                    )
                )
            }
        }
    }

    private func HandleNext() {
        if let onNext {
            onNext()
        } else {
            Task {
                do {
                    let session = try await viewModel.CreateTrip(using: tripService)
                    onTripCreated?(session)
                } catch {
                    // Error message is set in viewModel.errorMessage and shown in alert
                }
            }
        }
    }

    private func HandleTripRoomDismissed() {
        viewModel.createdSession = nil
        onBack?()
    }
}

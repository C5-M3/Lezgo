//
//  RoutePlanCardTests.swift
//  LezgoTests
//
//  Created by Farrell Sudjatmiko on 05/11/26.
//

import CoreLocation
import SwiftUI
import Testing
@testable import Lezgo

struct RoutePlanCardTests {
    private let sampleStart = RoutePoint(
        name: "Start",
        subtitle: "",
        coordinate: CLLocationCoordinate2D(latitude: -7.28, longitude: 112.63)
    )
    private let dest1 = RoutePoint(
        name: "Dest 1",
        subtitle: "",
        coordinate: CLLocationCoordinate2D(latitude: -7.29, longitude: 112.70)
    )
    private let dest2 = RoutePoint(
        name: "Dest 2",
        subtitle: "",
        coordinate: CLLocationCoordinate2D(latitude: -7.30, longitude: 112.72)
    )
    private let dest3 = RoutePoint(
        name: "Dest 3",
        subtitle: "",
        coordinate: CLLocationCoordinate2D(latitude: -7.31, longitude: 112.75)
    )

    @Test func AddDestinationButtonHiddenWhenDestinationsEmpty() {
        let card = RoutePlanCard(
            startPoint: sampleStart,
            destinations: [],
            activeSelection: nil,
            searchQuery: .constant(""),
            isStartPointLocked: false,
            isStopsExpanded: .constant(false),
            onSelectPointForEditing: { _ in },
            onClearSearch: {},
            onAddDestination: {},
            onRemoveDestination: { _ in },
            onMoveDestination: nil
        )

        #expect(!card.canAddDestination)
    }

    @Test func AddDestinationButtonShownWhenDestinationsExist() {
        let card = RoutePlanCard(
            startPoint: sampleStart,
            destinations: [dest1],
            activeSelection: nil,
            searchQuery: .constant(""),
            isStartPointLocked: false,
            isStopsExpanded: .constant(false),
            onSelectPointForEditing: { _ in },
            onClearSearch: {},
            onAddDestination: {},
            onRemoveDestination: { _ in },
            onMoveDestination: nil
        )

        #expect(card.canAddDestination)
    }

    @Test func AddDestinationButtonHiddenWhileSearchingOrEditing() {
        let card = RoutePlanCard(
            startPoint: sampleStart,
            destinations: [dest1],
            activeSelection: .destination(index: 1),
            searchQuery: .constant(""),
            isStartPointLocked: false,
            isStopsExpanded: .constant(false),
            onSelectPointForEditing: { _ in },
            onClearSearch: {},
            onAddDestination: {},
            onRemoveDestination: { _ in },
            onMoveDestination: nil
        )

        #expect(!card.canAddDestination)
    }

    @Test func IntermediateStopsEmptyWhenSingleDestination() {
        let card = RoutePlanCard(
            startPoint: sampleStart,
            destinations: [dest1],
            activeSelection: nil,
            searchQuery: .constant(""),
            isStartPointLocked: false,
            isStopsExpanded: .constant(false),
            onSelectPointForEditing: { _ in },
            onClearSearch: {},
            onAddDestination: {},
            onRemoveDestination: { _ in },
            onMoveDestination: nil
        )

        #expect(!card.isAddingNewDestination)
        #expect(card.intermediateStops.isEmpty)
        #expect(!card.isSearchingDestination)
    }

    @Test func IntermediateStopsShowsPreviousDestinationWhenAddingNewDestination() {
        let card = RoutePlanCard(
            startPoint: sampleStart,
            destinations: [dest1],
            activeSelection: .destination(index: 1),
            searchQuery: .constant("New Dest"),
            isStartPointLocked: false,
            isStopsExpanded: .constant(false),
            onSelectPointForEditing: { _ in },
            onClearSearch: {},
            onAddDestination: {},
            onRemoveDestination: { _ in },
            onMoveDestination: nil
        )

        #expect(card.isAddingNewDestination)
        #expect(card.intermediateStops.count == 1)
        #expect(card.intermediateStops.first?.name == "Dest 1")
        #expect(card.isSearchingDestination)
    }

    @Test func IntermediateStopsShowsAllDestinationsWhenAddingToMultipleDestinations() {
        let card = RoutePlanCard(
            startPoint: sampleStart,
            destinations: [dest1, dest2],
            activeSelection: .destination(index: 2),
            searchQuery: .constant(""),
            isStartPointLocked: false,
            isStopsExpanded: .constant(false),
            onSelectPointForEditing: { _ in },
            onClearSearch: {},
            onAddDestination: {},
            onRemoveDestination: { _ in },
            onMoveDestination: nil
        )

        #expect(card.isAddingNewDestination)
        #expect(card.intermediateStops.count == 2)
        #expect(card.intermediateStops.map(\.name) == ["Dest 1", "Dest 2"])
        #expect(card.isSearchingDestination)
    }

    @Test func IntermediateStopsExcludesLastDestinationWhenCollapsed() {
        let card = RoutePlanCard(
            startPoint: sampleStart,
            destinations: [dest1, dest2, dest3],
            activeSelection: nil,
            searchQuery: .constant(""),
            isStartPointLocked: false,
            isStopsExpanded: .constant(false),
            onSelectPointForEditing: { _ in },
            onClearSearch: {},
            onAddDestination: {},
            onRemoveDestination: { _ in },
            onMoveDestination: nil
        )

        #expect(!card.isAddingNewDestination)
        #expect(card.intermediateStops.count == 2)
        #expect(card.intermediateStops.map(\.name) == ["Dest 1", "Dest 2"])
        #expect(!card.isSearchingDestination)
    }

    private func Card(
        destinations: [RoutePoint],
        activeSelection: ActivePointSelection? = nil,
        isStopsExpanded: Bool = false
    ) -> RoutePlanCard {
        RoutePlanCard(
            startPoint: sampleStart,
            destinations: destinations,
            activeSelection: activeSelection,
            searchQuery: .constant(""),
            isStartPointLocked: false,
            isStopsExpanded: .constant(isStopsExpanded),
            onSelectPointForEditing: { _ in },
            onClearSearch: {},
            onAddDestination: {},
            onRemoveDestination: { _ in },
            onMoveDestination: nil
        )
    }

    @Test func OpenedStopsListEveryDestinationWithTheLastAsTheDestination() {
        let card = Card(destinations: [dest1, dest2, dest3], isStopsExpanded: true)

        #expect(card.isShowingAllStops)
        #expect(card.listedRows.map(\.name) == ["Dest 1", "Dest 2", "Dest 3"])
        #expect(card.IsFinalDestination(index: 2))
        #expect(!card.showsDestinationRow)
    }

    /// #295: one destination has nothing to reorder with.
    @Test func OneDestinationHasNoReorderHandle() {
        #expect(!Card(destinations: [dest1]).showsReorderHandle)
        #expect(Card(destinations: [dest1, dest2, dest3]).showsReorderHandle)
    }

    /// A stop shows no handle either while the one destination is still alone and a new one is being added.
    @Test func StopHasNoReorderHandleUntilTheNewDestinationIsAdded() {
        let card = Card(destinations: [dest1], activeSelection: .destination(index: 1))

        #expect(card.listedRows.map(\.name) == ["Dest 1"])
        #expect(!card.showsReorderHandle)
        #expect(Card(destinations: [dest1, dest2], activeSelection: .destination(index: 2)).showsReorderHandle)
    }

    /// #296: deleting stops from the opened list until fewer than two are left closes it, so no space is kept for it.
    @Test func OpenedStopsCloseWhenFewerThanTwoStopsAreLeft() {
        let card = Card(destinations: [dest1, dest2], isStopsExpanded: true)

        #expect(!card.showsStopsToggle)
        #expect(!card.isShowingAllStops)
    }

    /// #297: while adding, the old destination becomes a stop, so the closed stops count it and the search field is
    /// the destination row.
    @Test func StopsCountThePreviousDestinationWhileAdding() {
        let card = Card(destinations: [dest1, dest2], activeSelection: .destination(index: 2))

        #expect(card.showsStopsToggle)
        #expect(card.intermediateStops.count == 2)
        #expect(card.listedRows.isEmpty)
        #expect(card.showsDestinationRow)
    }

    /// #298: opening the stops while adding keeps the search field under them.
    @Test func SearchFieldStaysWhenTheStopsOpenWhileAdding() {
        let card = Card(destinations: [dest1, dest2], activeSelection: .destination(index: 2), isStopsExpanded: true)

        #expect(card.listedRows.map(\.name) == ["Dest 1", "Dest 2"])
        #expect(!card.IsFinalDestination(index: 1))
        #expect(card.showsDestinationRow)
    }

    /// #299: one stop and the destination are rows of one list, so dragging swaps them.
    @Test func OneStopAndTheDestinationAreListedTogether() {
        let card = Card(destinations: [dest1, dest2])

        #expect(!card.showsStopsToggle)
        #expect(card.listedRows.map(\.name) == ["Dest 1", "Dest 2"])
        #expect(card.IsFinalDestination(index: 1))
        #expect(!card.showsDestinationRow)
    }

    /// A row can be dragged only where it shows the handle: static rows must not lift.
    @Test func RowsAreStaticWhenThereIsNothingToReorder() {
        let card = Card(destinations: [dest1])

        #expect(!card.IsReorderable(index: 0))
    }

    @Test func EveryListedRowIsReorderableWithSeveralDestinations() {
        let card = Card(destinations: [dest1, dest2, dest3], isStopsExpanded: true)

        #expect([0, 1, 2].allSatisfy { card.IsReorderable(index: $0) })
    }

    @Test func RowBeingSearchedIsStatic() {
        let card = Card(
            destinations: [dest1, dest2, dest3],
            activeSelection: .destination(index: 1),
            isStopsExpanded: true
        )

        #expect(!card.IsReorderable(index: 1))
        #expect(card.IsReorderable(index: 0))
    }
}

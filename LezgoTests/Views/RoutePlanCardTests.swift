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

    @Test func IntermediateStopsExcludesLastDestinationWhenNotAdding() {
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
}

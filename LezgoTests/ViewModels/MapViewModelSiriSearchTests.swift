//
//  MapViewModelSiriSearchTests.swift
//  LezgoTests
//
//  Created by Nathan Sudiara on 12/11/26.
//

import Testing
@testable import Lezgo

/// Set Route opened by "Create a trip" from Siri searches for the place that was said (`specs/UserStories.md` → US-08).
@MainActor
struct MapViewModelSiriSearchTests {
    @Test func OnAppearFromSiriSearchesForThePlace() {
        let viewModel = MapViewModel()

        viewModel.onAppear(searchingFor: "Malang")

        #expect(viewModel.activeSelectionSheet == .destination(index: 0))
        #expect(viewModel.searchQuery == "Malang")
    }

    @Test func OnAppearWithoutAPlaceLeavesTheSearchEmpty() {
        let viewModel = MapViewModel()

        viewModel.onAppear(searchingFor: nil)

        #expect(viewModel.activeSelectionSheet == .destination(index: 0))
        #expect(viewModel.searchQuery.isEmpty)
    }
}

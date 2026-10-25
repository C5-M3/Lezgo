//
//  HomeViewModelTest.swift
//  LezgoTests
//
//  Created by Rizal Pratama on 25/10/26.
//

import CoreLocation
import Foundation
import MapKit
import SwiftUI
import Testing
@testable import Lezgo

// MARK: - Mocks

@MainActor
private final class MockMapService: NSObject, MapServiceProtocol {
    var userLocation: CLLocation?
    var authorizationStatus: CLAuthorizationStatus = .notDetermined
    var errorMessage: String?
    
    var requestLocationPermissionCalled = false
    var startUpdatingLocationCalled = false
    var stopUpdatingLocationCalled = false
    
    var isAuthorized: Bool {
        authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways
    }
    
    func requestLocationPermission() {
        requestLocationPermissionCalled = true
    }
    
    func startUpdatingLocation() {
        startUpdatingLocationCalled = true
    }
    
    func stopUpdatingLocation() {
        stopUpdatingLocationCalled = true
    }
}

@MainActor
private final class MockLocationSearchService: NSObject, LocationSearchServiceProtocol {
    var suggestions: [MKLocalSearchCompletion] = []
    var isSearching = false
    var selectedMapItem: MKMapItem?
    var errorMessage: String?
    
    var updatedQuery: String?
    var updatedRegion: MKCoordinateRegion?
    var clearSuggestionsCalled = false
    
    var stubbedSearchResults: [MKMapItem] = []
    var stubbedSelectedCompletionItem: MKMapItem?
    
    func updateQuery(_ query: String) {
        updatedQuery = query
    }
    
    func updateRegion(_ region: MKCoordinateRegion) {
        updatedRegion = region
    }
    
    func clearSuggestions() {
        suggestions = []
        clearSuggestionsCalled = true
    }
    
    func search(query: String, region: MKCoordinateRegion?) async -> [MKMapItem] {
        return stubbedSearchResults
    }
    
    func select(completion: MKLocalSearchCompletion) async -> MKMapItem? {
        if let item = stubbedSelectedCompletionItem {
            selectedMapItem = item
            return item
        }
        return nil
    }
}

// MARK: - Helpers

@MainActor
private func createMockMapItem(name: String, latitude: Double, longitude: Double) -> MKMapItem {
    let location = CLLocation(latitude: latitude, longitude: longitude)
    let mapItem = MKMapItem(location: location, address: nil)
    mapItem.name = name
    return mapItem
}

// MARK: - Tests

@Suite("HomeViewModel Tests")
@MainActor
struct HomeViewModelTest {
    
    @Test("Initial state should have default values")
    func initialState() {
        let mockMap = MockMapService()
        let mockSearch = MockLocationSearchService()
        let viewModel = HomeViewModel(mapService: mockMap, searchService: mockSearch)
        
        #expect(viewModel.searchText.isEmpty)
        #expect(viewModel.selectedMapItem == nil)
        #expect(viewModel.searchResults.isEmpty)
        #expect(viewModel.suggestions.isEmpty)
        #expect(viewModel.isSearching == false)
        #expect(viewModel.cameraPosition == .userLocation(fallback: .automatic))
    }
    
    @Test("Location access authorization flags should reflect status properly")
    func locationAuthorizationFlags() {
        let mockMap = MockMapService()
        let mockSearch = MockLocationSearchService()
        let viewModel = HomeViewModel(mapService: mockMap, searchService: mockSearch)
        
        // Not determined
        mockMap.authorizationStatus = .notDetermined
        mockMap.userLocation = nil
        #expect(viewModel.isLocationAccessDenied == false)
        #expect(viewModel.isLoadingLocation == true)
        
        // Denied
        mockMap.authorizationStatus = .denied
        #expect(viewModel.isLocationAccessDenied == true)
        #expect(viewModel.isLoadingLocation == true)
        
        // Restricted
        mockMap.authorizationStatus = .restricted
        #expect(viewModel.isLocationAccessDenied == true)
        
        // Authorized with location
        mockMap.authorizationStatus = .authorizedWhenInUse
        mockMap.userLocation = CLLocation(latitude: -6.2088, longitude: 106.8456)
        #expect(viewModel.isLocationAccessDenied == false)
        #expect(viewModel.isLoadingLocation == false)
    }
    
    @Test("onAppear should request permission and start updating if authorized")
    func onAppearBehavior() {
        let mockMap = MockMapService()
        let mockSearch = MockLocationSearchService()
        let viewModel = HomeViewModel(mapService: mockMap, searchService: mockSearch)
        
        // When not yet authorized
        mockMap.authorizationStatus = .notDetermined
        viewModel.onAppear()
        #expect(mockMap.requestLocationPermissionCalled == true)
        #expect(mockMap.startUpdatingLocationCalled == false)
        
        // When already authorized
        mockMap.requestLocationPermissionCalled = false
        mockMap.authorizationStatus = .authorizedWhenInUse
        viewModel.onAppear()
        #expect(mockMap.requestLocationPermissionCalled == true)
        #expect(mockMap.startUpdatingLocationCalled == true)
    }
    
    @Test("onSearchTextChanged should update query only when focused")
    func onSearchTextChanged() {
        let mockMap = MockMapService()
        let mockSearch = MockLocationSearchService()
        let viewModel = HomeViewModel(mapService: mockMap, searchService: mockSearch)
        
        viewModel.onSearchTextChanged("Monas", isFocused: true)
        #expect(viewModel.searchText == "Monas")
        #expect(mockSearch.updatedQuery == "Monas")
        
        viewModel.onSearchTextChanged("Bandung", isFocused: false)
        #expect(viewModel.searchText == "Bandung")
        #expect(mockSearch.updatedQuery == "Monas") // Belum terupdate karena isFocused false
    }
    
    @Test("onUserLocationChanged should update region on searchService")
    func onUserLocationChanged() {
        let mockMap = MockMapService()
        let mockSearch = MockLocationSearchService()
        let viewModel = HomeViewModel(mapService: mockMap, searchService: mockSearch)
        
        viewModel.onUserLocationChanged(nil)
        #expect(mockSearch.updatedRegion == nil)
        
        let location = CLLocation(latitude: -6.2000, longitude: 106.8166)
        viewModel.onUserLocationChanged(location)
        #expect(mockSearch.updatedRegion != nil)
        #expect(mockSearch.updatedRegion?.center.latitude == location.coordinate.latitude)
        #expect(mockSearch.updatedRegion?.center.longitude == location.coordinate.longitude)
    }
    
    @Test("performSearch with results should update searchResults and selected item")
    func performSearchWithResults() async {
        let mockMap = MockMapService()
        let mockSearch = MockLocationSearchService()
        let viewModel = HomeViewModel(mapService: mockMap, searchService: mockSearch)
        
        let item1 = createMockMapItem(name: "Monumen Nasional", latitude: -6.1754, longitude: 106.8272)
        let item2 = createMockMapItem(name: "Kota Tua Jakarta", latitude: -6.1376, longitude: 106.8171)
        mockSearch.stubbedSearchResults = [item1, item2]
        
        viewModel.searchText = "Jakarta"
        await viewModel.performSearch()
        
        #expect(viewModel.searchResults.count == 2)
        #expect(viewModel.selectedMapItem?.name == "Monumen Nasional")
        #expect(mockSearch.clearSuggestionsCalled == true)
    }
    
    @Test("performSearch with empty results should clear searchResults without selecting item")
    func performSearchWithEmptyResults() async {
        let mockMap = MockMapService()
        let mockSearch = MockLocationSearchService()
        let viewModel = HomeViewModel(mapService: mockMap, searchService: mockSearch)
        
        mockSearch.stubbedSearchResults = []
        viewModel.searchText = "Unknown"
        await viewModel.performSearch()
        
        #expect(viewModel.searchResults.isEmpty)
        #expect(viewModel.selectedMapItem == nil)
        #expect(mockSearch.clearSuggestionsCalled == true)
    }
    
    @Test("selectSuggestion should select mapItem and update search text")
    func selectSuggestion() async {
        let mockMap = MockMapService()
        let mockSearch = MockLocationSearchService()
        let viewModel = HomeViewModel(mapService: mockMap, searchService: mockSearch)
        
        let item = createMockMapItem(name: "Kuta Beach", latitude: -8.7185, longitude: 115.1686)
        mockSearch.stubbedSelectedCompletionItem = item
        
        let completion = MKLocalSearchCompletion()
        await viewModel.selectSuggestion(completion)
        
        #expect(viewModel.selectedMapItem?.name == "Kuta Beach")
        #expect(viewModel.searchText == "Kuta Beach")
        #expect(mockSearch.clearSuggestionsCalled == true)
    }
    
    @Test("resetSearchAndCenterOnUser should reset search states and camera position")
    func resetSearchAndCenterOnUser() {
        let mockMap = MockMapService()
        let mockSearch = MockLocationSearchService()
        let viewModel = HomeViewModel(mapService: mockMap, searchService: mockSearch)
        
        let item = createMockMapItem(name: "Test Location", latitude: -6.0, longitude: 106.0)
        viewModel.searchText = "Some Query"
        viewModel.selectedMapItem = item
        viewModel.searchResults = [item]
        viewModel.cameraPosition = .region(
            MKCoordinateRegion(
                center: item.location.coordinate,
                latitudinalMeters: 1000,
                longitudinalMeters: 1000
            )
        )
        
        viewModel.resetSearchAndCenterOnUser()
        
        #expect(viewModel.searchText.isEmpty)
        #expect(viewModel.selectedMapItem == nil)
        #expect(viewModel.searchResults.isEmpty)
        #expect(mockSearch.clearSuggestionsCalled == true)
        #expect(viewModel.cameraPosition == .userLocation(fallback: .automatic))
    }
}

//
//  HomeViewModel.swift
//  Lezgo
//
//  Created by Rizal Pratama on 25/10/26.
//

import CoreLocation
import Foundation
import MapKit
import SwiftUI

/// Protokol untuk layanan peta dan manajemen izin lokasi pengguna.
@MainActor
public protocol MapServiceProtocol: AnyObject, Observable {
    var userLocation: CLLocation? { get set }
    var authorizationStatus: CLAuthorizationStatus { get set }
    var errorMessage: String? { get set }
    var isAuthorized: Bool { get }
    
    func requestLocationPermission()
    func startUpdatingLocation()
    func stopUpdatingLocation()
}

/// Protokol untuk layanan pencarian lokasi dan rekomendasi tempat.
@MainActor
public protocol LocationSearchServiceProtocol: AnyObject, Observable {
    var suggestions: [MKLocalSearchCompletion] { get set }
    var isSearching: Bool { get set }
    var selectedMapItem: MKMapItem? { get set }
    var errorMessage: String? { get set }
    
    func updateQuery(_ query: String)
    func updateRegion(_ region: MKCoordinateRegion)
    func clearSuggestions()
    func search(query: String, region: MKCoordinateRegion?) async -> [MKMapItem]
    func select(completion: MKLocalSearchCompletion) async -> MKMapItem?
}

extension MapService: MapServiceProtocol {}
extension LocationSearchService: LocationSearchServiceProtocol {}

/// ViewModel untuk mengelola status antarmuka dan interaksi pada `HomeView`.
@Observable
@MainActor
final class HomeViewModel {
    // MARK: - Dependencies
    var mapService: any MapServiceProtocol
    var searchService: any LocationSearchServiceProtocol
    
    // MARK: - State Properties
    var cameraPosition: MapCameraPosition = .userLocation(fallback: .automatic)
    var searchText: String = ""
    var selectedMapItem: MKMapItem?
    var searchResults: [MKMapItem] = []
    
    // MARK: - Computed Properties
    var suggestions: [MKLocalSearchCompletion] {
        searchService.suggestions
    }
    
    var isSearching: Bool {
        searchService.isSearching
    }
    
    var isLocationAccessDenied: Bool {
        mapService.authorizationStatus == .denied || mapService.authorizationStatus == .restricted
    }
    
    var isLoadingLocation: Bool {
        mapService.userLocation == nil && !mapService.isAuthorized
    }
    
    // MARK: - Initializer
    init(
        mapService: any MapServiceProtocol,
        searchService: any LocationSearchServiceProtocol
    ) {
        self.mapService = mapService
        self.searchService = searchService
    }
    
    convenience init() {
        self.init(
            mapService: MapService(),
            searchService: LocationSearchService()
        )
    }
    
    // MARK: - Lifecycle & Events
    
    /// Dipanggil saat tampilan muncul untuk meminta izin dan memperbarui lokasi.
    func onAppear() {
        mapService.requestLocationPermission()
        if mapService.isAuthorized {
            mapService.startUpdatingLocation()
        }
    }
    
    /// Menangani perubahan teks pencarian saat kolom pencarian sedang fokus.
    func onSearchTextChanged(_ newValue: String, isFocused: Bool = true) {
        searchText = newValue
        if isFocused {
            searchService.updateQuery(newValue)
        }
    }
    
    /// Menangani pembaruan lokasi pengguna untuk mempersempit wilayah pencarian.
    func onUserLocationChanged(_ newLocation: CLLocation?) {
        guard let newLocation else { return }
        searchService.updateRegion(
            MKCoordinateRegion(
                center: newLocation.coordinate,
                latitudinalMeters: 25_000,
                longitudinalMeters: 25_000
            )
        )
    }
    
    // MARK: - Search & Selection Actions
    
    /// Melakukan pencarian lokasi berdasarkan teks pencarian saat ini.
    func performSearch() async {
        let items = await searchService.search(query: searchText, region: nil)
        searchResults = items
        searchService.clearSuggestions()
        
        if let first = items.first {
            selectedMapItem = first
            withAnimation {
                cameraPosition = .region(
                    MKCoordinateRegion(
                        center: first.location.coordinate,
                        latitudinalMeters: 2_000,
                        longitudinalMeters: 2_000
                    )
                )
            }
        }
    }
    
    /// Memilih salah satu saran dari hasil autocomplete.
    func selectSuggestion(_ suggestion: MKLocalSearchCompletion) async {
        searchService.clearSuggestions()
        
        if let item = await searchService.select(completion: suggestion) {
            selectedMapItem = item
            searchText = item.name ?? suggestion.title
            searchService.clearSuggestions()
            
            withAnimation {
                cameraPosition = .region(
                    MKCoordinateRegion(
                        center: item.location.coordinate,
                        latitudinalMeters: 1_500,
                        longitudinalMeters: 1_500
                    )
                )
            }
        }
    }
    
    /// Mereset pencarian dan mengembalikan kamera ke lokasi pengguna.
    func resetSearchAndCenterOnUser() {
        searchText = ""
        selectedMapItem = nil
        searchResults = []
        searchService.clearSuggestions()
        withAnimation {
            cameraPosition = .userLocation(fallback: .automatic)
        }
    }
}

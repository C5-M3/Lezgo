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
final class HomeViewModel {
    // MARK: - Dependencies
    var mapService: any MapServiceProtocol
    var searchService: any LocationSearchServiceProtocol
    let activeTripStorage: any ActiveTripStorage

    // MARK: - State Properties
    var cameraPosition: MapCameraPosition = .userLocation(fallback: .automatic)
    var searchText: String = ""
    var selectedMapItem: MKMapItem?
    var searchResults: [MKMapItem] = []
    var activeDraftTrip: ActiveTripSummary?
    var lastTripEndedNotice: String?

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
        searchService: any LocationSearchServiceProtocol,
        activeTripStorage: (any ActiveTripStorage)? = nil
    ) {
        self.mapService = mapService
        self.searchService = searchService
        let storage = activeTripStorage ?? UserDefaultsActiveTripStorage()
        self.activeTripStorage = storage
        self.activeDraftTrip = storage.LoadActiveTrip()
    }

    convenience init() {
        self.init(
            mapService: MapService(),
            searchService: LocationSearchService()
        )
    }

    // MARK: - Lifecycle & Events

    /// Dipanggil saat tampilan muncul untuk meminta izin dan memperbarui lokasi serta memeriksa draf perjalanan.
    func onAppear() {
        CheckActiveDraftTrip()
        mapService.requestLocationPermission()
        if mapService.isAuthorized {
            mapService.startUpdatingLocation()
        }
    }

    /// Memeriksa apakah ada draf perjalanan yang tersimpan di perangkat (US-03).
    func CheckActiveDraftTrip() {
        activeDraftTrip = activeTripStorage.LoadActiveTrip()
    }

    /// Menghapus draf perjalanan dari penyimpanan lokal.
    func ClearActiveDraftTrip() {
        activeTripStorage.ClearActiveTrip()
        activeDraftTrip = nil
    }

    /// Bergabung dengan perjalanan menggunakan kode 6 digit dan menyimpan draft trip (US-02, US-03).
    @discardableResult
    func JoinTrip(roomCode: String, tripService: any TripService) async -> Bool {
        do {
            let session = try await tripService.JoinTrip(roomCode: roomCode, profile: nil)
            guard session.state.trip.status == .lobby else {
                try? await tripService.ExitTrip(tripID: session.state.trip.id, participantID: session.myParticipantID)
                return false
            }
            let summary = ActiveTripSummary.From(session: session)
            activeTripStorage.SaveActiveTrip(summary)
            activeDraftTrip = summary
            return true
        } catch {
            return false
        }
    }

    /// Menangani sesi perjalanan yang berhasil diverifikasi dan bergabung (US-02).
    func onTripJoined(_ session: TripSession) {
        guard session.state.trip.status == .lobby else { return }
        let summary = ActiveTripSummary.From(session: session)
        activeTripStorage.SaveActiveTrip(summary)
        activeDraftTrip = summary
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

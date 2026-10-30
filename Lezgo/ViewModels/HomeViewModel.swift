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
    var activeTripSession: TripSession?
    var activeMapSession: TripSession?
    var isTransitioningToTripMap: Bool = false
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

    /// Bergabung dengan perjalanan menggunakan kode 6 digit dan menyiapkan sesi Trip Room (US-02, US-03).
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
            activeDraftTrip = nil
            activeTripSession = session
            return true
        } catch {
            return false
        }
    }

    /// Menangani sesi perjalanan yang berhasil diverifikasi dan bergabung (US-02).
    /// Mengarahkan langsung ke Trip Room tanpa menampilkan layar Draft Trip.
    /// Draft trip hanya akan dimuat dari storage saat aplikasi ditutup dan dibuka kembali.
    func onTripJoined(_ session: TripSession) {
        guard session.state.trip.status == .lobby else { return }
        let summary = ActiveTripSummary.From(session: session)
        activeTripStorage.SaveActiveTrip(summary)
        activeDraftTrip = nil
        activeTripSession = session
    }

    /// Melanjutkan draft perjalanan yang tersimpan ke Trip Room (LOBBY) atau Trip Maps (IN_TRIP) (US-03).
    func continueDraftTrip(tripService: any TripService) async {
        guard let draft = activeDraftTrip else { return }
        guard draft.status.isOpen else {
            handleDraftTripEnded()
            return
        }

        do {
            let state = try await tripService.FetchTrip(tripID: draft.tripID)
            guard state.trip.status.isOpen else {
                handleDraftTripEnded()
                return
            }
            applyActiveSession(
                TripSession(myParticipantID: draft.myParticipantID, state: state),
                isInTrip: state.trip.status == .inTrip
            )
        } catch let error as TripServiceError where error == .notFound || error == .tripEnded {
            handleDraftTripEnded()
        } catch {
            let fallback = fallbackSession(for: draft)
            applyActiveSession(fallback, isInTrip: draft.status == .inTrip)
        }
    }

    private func fallbackSession(for draft: ActiveTripSummary) -> TripSession {
        let fallbackTrip = Trip(
            id: draft.tripID,
            roomCode: draft.roomCode,
            status: draft.status,
            leaderParticipantID: draft.isLeader ? draft.myParticipantID : UUID(),
            currentWaypointIndex: 0,
            routeVersion: 1,
            createdAt: Date(),
            startedAt: nil,
            endedAt: nil
        )
        let fallbackState = TripState(
            trip: fallbackTrip,
            waypoints: [],
            participants: [],
            route: nil
        )
        return TripSession(myParticipantID: draft.myParticipantID, state: fallbackState)
    }

    private func applyActiveSession(_ session: TripSession, isInTrip: Bool) {
        activeDraftTrip = nil
        if isInTrip {
            activeMapSession = session
            activeTripSession = nil
        } else {
            activeTripSession = session
            activeMapSession = nil
        }
    }

    /// Menangani saat trip yang tersimpan ternyata sudah berakhir saat aplikasi dibuka kembali (US-03).
    func handleDraftTripEnded() {
        activeTripStorage.ClearActiveTrip()
        activeDraftTrip = nil
        lastTripEndedNotice = String(localized: "Your last trip has ended.")
    }

    /// Menangani saat user keluar atau mengakhiri trip dari Trip Map View (US-07).
    func onMapSessionClosed() {
        activeTripStorage.ClearActiveTrip()
        activeDraftTrip = nil
        activeMapSession = nil
    }

    /// Menangani transisi saat trip dimulai dari Trip Room ke Trip Maps (US-05, US-06).
    func onTripStartedFromRoom(session: TripSession) {
        isTransitioningToTripMap = true
        activeTripSession = nil
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(300))
            self.activeMapSession = session
            self.isTransitioningToTripMap = false
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

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
    /// `true` from a New Destination until the Trip Room is open, so closing the map does not end the trip here.
    private(set) var isReturningToTripRoom = false
    var lastTripEndedNotice: String?
    /// Why the saved trip could not be opened; the draft stays so the person can try again.
    var draftTripErrorMessage: String?
    /// How many times Continue tries to load the saved trip before saying it could not.
    private static let draftTripFetchAttempts = 3
    /// The room code from the last invite link that opened the app; "Enter room code" opens with it filled in.
    var inviteRoomCode: String?

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
            onTripJoined(session)
            return true
        } catch {
            return false
        }
    }

    /// Menangani sesi perjalanan yang berhasil diverifikasi dan bergabung (US-02).
    /// Opens the Trip Room for a `LOBBY` trip and the map for an `IN_TRIP` trip (a late member), without the Draft
    /// Trip screen. Draft trip hanya akan dimuat dari storage saat aplikasi ditutup dan dibuka kembali.
    func onTripJoined(_ session: TripSession) {
        guard session.state.trip.status.isOpen else { return }
        activeTripStorage.SaveActiveTrip(ActiveTripSummary.From(session: session))
        applyActiveSession(session, isInTrip: session.state.trip.status == .inTrip)
    }

    /// Melanjutkan draft perjalanan yang tersimpan ke Trip Room (LOBBY) atau Trip Maps (IN_TRIP) (US-03).
    ///
    /// Right after the app opens, iCloud may need a moment, so a failed fetch is tried twice more. If the trip still
    /// cannot be loaded, the draft stays with a message: opening the room or map without the route and the cars
    /// would look as if the trip was lost.
    func continueDraftTrip(tripService: any TripService, retryDelay: Duration = .seconds(1)) async {
        guard let draft = activeDraftTrip else { return }
        guard draft.status.isOpen else {
            handleDraftTripEnded()
            return
        }
        draftTripErrorMessage = nil

        for attempt in 1...Self.draftTripFetchAttempts {
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
                return
            } catch let error as TripServiceError where error == .notFound || error == .tripEnded {
                handleDraftTripEnded()
                return
            } catch {
                guard attempt < Self.draftTripFetchAttempts else { break }
                try? await Task.sleep(for: retryDelay)
            }
        }
        draftTripErrorMessage = String(localized: "Couldn't open your trip. Check your connection and try again.")
    }

    /// "OK" on the message that the saved trip could not be opened.
    func DismissDraftTripError() {
        draftTripErrorMessage = nil
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
        // The map's cover also reports its dismissal on the way back to the Trip Room, possibly after the room is
        // open; the trip goes on then.
        guard !isReturningToTripRoom, activeTripSession == nil else { return }
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

    /// After a New Destination the trip is back in `LOBBY`: the map closes and the Trip Room opens with the new route
    /// (US-07). The map already saved the trip with its new status.
    func onReturnedToTripRoom(_ session: TripSession) {
        isReturningToTripRoom = true
        activeMapSession = nil
        Task { @MainActor in
            // One full-screen cover has to finish closing before the next one can open.
            try? await Task.sleep(for: .milliseconds(300))
            self.activeTripSession = session
            self.isReturningToTripRoom = false
        }
    }

    /// Reads the room code from an invite link (US-02). Any other link is ignored, so a bad link never clears a code.
    func OpenInviteLink(_ url: URL) {
        guard let roomCode = InviteLink.RoomCode(from: url) else { return }
        inviteRoomCode = roomCode
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

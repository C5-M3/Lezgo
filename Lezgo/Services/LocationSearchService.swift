//
//  LocationSearchService.swift
//  Lezgo
//
//  Created by Rizal Pratama on 25/10/26.
//

import Foundation
import MapKit

/// Layanan pencarian tempat dan rekomendasi alamat berbasis MapKit (Apple Maps).
/// Menggunakan `MKLocalSearchCompleter` untuk rekomendasi otomatis (autocomplete)
/// dan `MKLocalSearch` untuk mengambil detail koordinat dan informasi lokasi.
@Observable
@MainActor
final class LocationSearchService: NSObject, MKLocalSearchCompleterDelegate {
    private let completer = MKLocalSearchCompleter()
    
    var suggestions: [MKLocalSearchCompletion] = []
    var isSearching: Bool = false
    var selectedMapItem: MKMapItem?
    var errorMessage: String?
    
    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = [.address, .pointOfInterest]
    }
    
    /// Memperbarui kueri pencarian untuk mendapatkan saran lokasi terkini secara real-time.
    func updateQuery(_ query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            completer.queryFragment = ""
            suggestions = []
        } else {
            completer.queryFragment = trimmed
        }
    }
    
    /// Mengatur wilayah preferensi pencarian (misalnya di sekitar lokasi pengguna).
    func updateRegion(_ region: MKCoordinateRegion) {
        completer.region = region
    }
    
    /// Mengosongkan saran pencarian.
    func clearSuggestions() {
        completer.queryFragment = ""
        suggestions = []
    }
    
    // MARK: - MKLocalSearchCompleterDelegate
    
    nonisolated func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        Task { @MainActor in
            self.suggestions = completer.results
        }
    }
    
    nonisolated func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        Task { @MainActor in
            self.errorMessage = error.localizedDescription
        }
    }
    
    // MARK: - Search Execution
    
    /// Mencari lokasi berdasarkan teks langsung menggunakan `MKLocalSearch`.
    func search(query: String, region: MKCoordinateRegion? = nil) async -> [MKMapItem] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        
        isSearching = true
        defer { isSearching = false }
        
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = trimmed
        if let region {
            request.region = region
        }
        request.resultTypes = [.address, .pointOfInterest]
        
        let search = MKLocalSearch(request: request)
        do {
            let response = try await search.start()
            return response.mapItems
        } catch {
            errorMessage = error.localizedDescription
            return []
        }
    }
    
    /// Mengambil detail `MKMapItem` dari saran `MKLocalSearchCompletion` yang dipilih.
    func select(completion: MKLocalSearchCompletion) async -> MKMapItem? {
        isSearching = true
        defer { isSearching = false }
        
        let request = MKLocalSearch.Request(completion: completion)
        let search = MKLocalSearch(request: request)
        do {
            let response = try await search.start()
            let item = response.mapItems.first
            self.selectedMapItem = item
            return item
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }
}

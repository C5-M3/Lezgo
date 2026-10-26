//
//  LocationSearchService.swift
//  Lezgo
//
//  Created by Farrell Sudjatmiko on 26/10/26.
//


import Foundation
import MapKit

@Observable
final class LocationSearchService: NSObject, MKLocalSearchCompleterDelegate {
    private let completer = MKLocalSearchCompleter()
    var searchResults: [MKLocalSearchCompletion] = []
    var isSearching: Bool = false

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = [.address, .pointOfInterest]
    }

    func updateQueryFragment(_ fragment: String) {
        let trimmed = fragment.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            searchResults = []
            isSearching = false
            completer.queryFragment = ""
        } else {
            isSearching = true
            completer.queryFragment = trimmed
        }
    }

    func resolveLocation(from completion: MKLocalSearchCompletion) async throws -> RoutePoint {
        let request = MKLocalSearch.Request(completion: completion)
        let search = MKLocalSearch(request: request)
        let response = try await search.start()

        guard let mapItem = response.mapItems.first else {
            throw NSError(domain: "LocationSearch", code: 404, userInfo: [NSLocalizedDescriptionKey: "No coordinate found."])
        }

        return RoutePoint(
            name: completion.title,
            subtitle: completion.subtitle,
            coordinate: mapItem.placemark.coordinate
        )
    }

    // MARK: - MKLocalSearchCompleterDelegate
    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        self.searchResults = completer.results
        self.isSearching = false
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        self.searchResults = []
        self.isSearching = false
    }
}

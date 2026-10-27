//
//  LocationSearchService.swift
//  Lezgo
//
//  Created by Farrell Sudjatmiko on 26/10/26.
//


import Foundation
import MapKit
import CoreLocation

struct SearchResultItem: Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    let completion: MKLocalSearchCompletion?
    var coordinate: CLLocationCoordinate2D?
    var distanceInMeters: CLLocationDistance?
    var isCalculatingDistance: Bool = false

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: SearchResultItem, rhs: SearchResultItem) -> Bool {
        lhs.id == rhs.id
    }
}

@Observable
final class LocationSearchService: NSObject, MKLocalSearchCompleterDelegate {
    private let completer = MKLocalSearchCompleter()
    var searchResults: [SearchResultItem] = []
    var isSearching: Bool = false
    var referenceLocation: CLLocationCoordinate2D?

    // Cache for resolved coordinates by item ID (title + subtitle)
    private var coordinateCache: [String: CLLocationCoordinate2D] = [:]
    private var enrichmentTask: Task<Void, Never>?

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = [.address, .pointOfInterest]
    }

    func updateQueryFragment(_ fragment: String, referenceLocation: CLLocationCoordinate2D? = nil) {
        self.referenceLocation = referenceLocation
        let trimmed = fragment.trimmingCharacters(in: .whitespacesAndNewlines)

        enrichmentTask?.cancel()

        guard !trimmed.isEmpty else {
            searchResults = []
            isSearching = false
            completer.queryFragment = ""
            return
        }

        isSearching = true

        if let ref = referenceLocation {
            completer.region = MKCoordinateRegion(
                center: ref,
                latitudinalMeters: 50_000,
                longitudinalMeters: 50_000
            )
        }

        completer.queryFragment = trimmed
    }

    func resolveLocation(from item: SearchResultItem) async throws -> RoutePoint {
        if let coord = item.coordinate ?? coordinateCache[item.id] {
            return RoutePoint(
                name: item.title,
                subtitle: item.subtitle,
                coordinate: coord
            )
        }

        let request: MKLocalSearch.Request
        if let completion = item.completion {
            request = MKLocalSearch.Request(completion: completion)
        } else {
            request = MKLocalSearch.Request()
            request.naturalLanguageQuery = "\(item.title) \(item.subtitle)"
        }

        let search = MKLocalSearch(request: request)
        let response = try await search.start()

        guard let mapItem = response.mapItems.first else {
            throw NSError(domain: "LocationSearch", code: 404, userInfo: [NSLocalizedDescriptionKey: "No coordinate found."])
        }

        let coord = mapItem.placemark.coordinate
        coordinateCache[item.id] = coord

        return RoutePoint(
            name: item.title,
            subtitle: item.subtitle,
            coordinate: coord
        )
    }

    // MARK: - MKLocalSearchCompleterDelegate
    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        let completions = completer.results
        let hasRef = referenceLocation != nil
        let refCoord = referenceLocation

        // Populate items immediately, checking the cache for any already-resolved coordinates
        var items: [SearchResultItem] = []
        for comp in completions {
            let itemId = "\(comp.title)_\(comp.subtitle)"
            let cachedCoord = coordinateCache[itemId]

            var dist: CLLocationDistance?
            if let cached = cachedCoord, let ref = refCoord {
                let from = CLLocation(latitude: ref.latitude, longitude: ref.longitude)
                let to = CLLocation(latitude: cached.latitude, longitude: cached.longitude)
                dist = from.distance(from: to)
            }

            items.append(SearchResultItem(
                id: itemId,
                title: comp.title,
                subtitle: comp.subtitle,
                completion: comp,
                coordinate: cachedCoord,
                distanceInMeters: dist,
                isCalculatingDistance: hasRef && cachedCoord == nil
            ))
        }

        self.searchResults = items
        self.isSearching = false

        // Cancel any pending enrichment from previous keystrokes
        enrichmentTask?.cancel()
        guard let ref = referenceLocation, !items.isEmpty else { return }

        // Items that still need distance calculation (top 6 items to conserve requests)
        let uncalcBatch = Array(items.filter { $0.coordinate == nil }.prefix(6))
        guard !uncalcBatch.isEmpty else { return }

        // Debounce by 350ms so typing fast does not fire search requests until the user pauses
        enrichmentTask = Task { [weak self] in
            do {
                try await Task.sleep(for: .milliseconds(350))
            } catch {
                return
            }

            guard !Task.isCancelled else { return }

            await withTaskGroup(of: (String, CLLocationCoordinate2D, CLLocationDistance)?.self) { group in
                for item in uncalcBatch {
                    guard let comp = item.completion else { continue }
                    group.addTask {
                        guard !Task.isCancelled else { return nil }
                        do {
                            let request = MKLocalSearch.Request(completion: comp)
                            let search = MKLocalSearch(request: request)
                            let response = try await search.start()
                            guard !Task.isCancelled, let mapItem = response.mapItems.first else { return nil }

                            let coord = mapItem.placemark.coordinate
                            let from = CLLocation(latitude: ref.latitude, longitude: ref.longitude)
                            let to = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
                            let dist = from.distance(from: to)
                            return (item.id, coord, dist)
                        } catch {
                            return nil
                        }
                    }
                }

                for await result in group {
                    guard !Task.isCancelled else { continue }
                    if let (id, coord, dist) = result {
                        await MainActor.run {
                            guard let self = self else { return }
                            self.coordinateCache[id] = coord
                            if let idx = self.searchResults.firstIndex(where: { $0.id == id }) {
                                self.searchResults[idx].coordinate = coord
                                self.searchResults[idx].distanceInMeters = dist
                                self.searchResults[idx].isCalculatingDistance = false
                            }
                        }
                    }
                }

                // Any items that finished or failed can turn off the calculating placeholder
                await MainActor.run {
                    guard let self = self else { return }
                    for i in self.searchResults.indices where self.searchResults[i].isCalculatingDistance {
                        self.searchResults[i].isCalculatingDistance = false
                    }
                }
            }
        }
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        self.searchResults = []
        self.isSearching = false
    }
}

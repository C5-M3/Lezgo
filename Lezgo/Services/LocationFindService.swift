//
//  LocationFindService.swift
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
final class LocationFindService: NSObject, MKLocalSearchCompleterDelegate {
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
            let errorInfo = [NSLocalizedDescriptionKey: "No coordinate found."]
            throw NSError(domain: "LocationSearch", code: 404, userInfo: errorInfo)
        }

        let coord = mapItem.location.coordinate
        coordinateCache[item.id] = coord

        return RoutePoint(
            name: item.title,
            subtitle: item.subtitle,
            coordinate: coord
        )
    }

    // MARK: - MKLocalSearchCompleterDelegate
    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        let items = buildSearchResultItems(from: completer.results)
        self.searchResults = items
        self.isSearching = false

        enrichmentTask?.cancel()
        guard let ref = referenceLocation, !items.isEmpty else { return }

        let uncalcBatch = Array(items.filter { $0.coordinate == nil }.prefix(6))
        guard !uncalcBatch.isEmpty else { return }

        enrichmentTask = Task { [weak self] in
            await self?.enrichBatchWithDistances(uncalcBatch, referenceLocation: ref)
        }
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        self.searchResults = []
        self.isSearching = false
    }

    // MARK: - Helpers
    private func buildSearchResultItems(from completions: [MKLocalSearchCompletion]) -> [SearchResultItem] {
        let hasRef = referenceLocation != nil
        let refCoord = referenceLocation

        return completions.map { comp in
            let itemId = "\(comp.title)_\(comp.subtitle)"
            let cachedCoord = coordinateCache[itemId]
            var dist: CLLocationDistance?

            if let cached = cachedCoord, let ref = refCoord {
                let from = CLLocation(latitude: ref.latitude, longitude: ref.longitude)
                let to = CLLocation(latitude: cached.latitude, longitude: cached.longitude)
                dist = from.distance(from: to)
            }

            return SearchResultItem(
                id: itemId,
                title: comp.title,
                subtitle: comp.subtitle,
                completion: comp,
                coordinate: cachedCoord,
                distanceInMeters: dist,
                isCalculatingDistance: hasRef && cachedCoord == nil
            )
        }
    }

    private struct EnrichmentResult {
        let id: String
        let coordinate: CLLocationCoordinate2D
        let distance: CLLocationDistance
    }

    private func enrichBatchWithDistances(
        _ batch: [SearchResultItem],
        referenceLocation ref: CLLocationCoordinate2D
    ) async {
        do {
            try await Task.sleep(for: .milliseconds(350))
        } catch {
            return
        }

        guard !Task.isCancelled else { return }

        await withTaskGroup(of: EnrichmentResult?.self) { group in
            for item in batch {
                guard let comp = item.completion else { continue }
                group.addTask {
                    await self.fetchCoordinateAndDistance(for: item.id, completion: comp, referenceLocation: ref)
                }
            }

            for await result in group {
                guard !Task.isCancelled, let enrichment = result else { continue }
                await MainActor.run {
                    self.coordinateCache[enrichment.id] = enrichment.coordinate
                    if let index = self.searchResults.firstIndex(where: { $0.id == enrichment.id }) {
                        self.searchResults[index].coordinate = enrichment.coordinate
                        self.searchResults[index].distanceInMeters = enrichment.distance
                        self.searchResults[index].isCalculatingDistance = false
                    }
                }
            }

            await MainActor.run {
                for index in self.searchResults.indices where self.searchResults[index].isCalculatingDistance {
                    self.searchResults[index].isCalculatingDistance = false
                }
            }
        }
    }

    private func fetchCoordinateAndDistance(
        for id: String,
        completion: MKLocalSearchCompletion,
        referenceLocation ref: CLLocationCoordinate2D
    ) async -> EnrichmentResult? {
        guard !Task.isCancelled else { return nil }
        do {
            let request = MKLocalSearch.Request(completion: completion)
            let search = MKLocalSearch(request: request)
            let response = try await search.start()
            guard !Task.isCancelled, let mapItem = response.mapItems.first else { return nil }

            let coord = mapItem.location.coordinate
            let from = CLLocation(latitude: ref.latitude, longitude: ref.longitude)
            let to = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
            let dist = from.distance(from: to)
            return EnrichmentResult(id: id, coordinate: coord, distance: dist)
        } catch {
            return nil
        }
    }
}

//
//  TripRecapViewModel.swift
//  Lezgo
//
//  Created by Rizal Pratama on 16/11/26.
//

import Foundation
import Observation

@Observable
@MainActor
final class TripRecapViewModel {
    enum SortOrder: Hashable {
        case newest
        case oldest
        case distance
    }

    enum FilterCategory: Hashable {
        case all
    }

    private let recapService: any TripRecapService
    private let storage: (any TripRecapStorage)?

    var recaps: [TripRecap] = []
    var searchQuery: String = ""
    var sortOrder: SortOrder = .newest
    var selectedFilter: FilterCategory = .all
    var isLoading: Bool = false
    var errorMessage: String?

    var filteredRecaps: [TripRecap] {
        var result = recaps

        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !query.isEmpty {
            result = result.filter { item in
                item.destinationName.lowercased().contains(query)
                    || item.destinationLabel.lowercased().contains(query)
                    || item.formattedDate.lowercased().contains(query)
            }
        }

        switch sortOrder {
        case .newest:
            result.sort { $0.date > $1.date }
        case .oldest:
            result.sort { $0.date < $1.date }
        case .distance:
            result.sort { $0.distanceText > $1.distanceText }
        }

        return result
    }

    init(
        recapService: any TripRecapService,
        storage: (any TripRecapStorage)? = nil
    ) {
        self.recapService = recapService
        self.storage = storage
        let loaded = storage?.loadRecaps() ?? []
        self.recaps = loaded
        self.isLoading = loaded.isEmpty
    }

    convenience init(database: any CloudDatabase) {
        self.init(recapService: CloudKitTripRecapService(database: database), storage: UserDefaultsTripRecapStorage())
    }

    convenience init(storage: any TripRecapStorage) {
        self.init(recapService: StorageTripRecapService(storage: storage), storage: storage)
    }

    convenience init() {
        self.init(recapService: CloudKitTripRecapService(), storage: UserDefaultsTripRecapStorage())
    }

    func loadRecaps() async {
        isLoading = true
        errorMessage = nil
        do {
            let fetched = try await recapService.fetchRecaps()
            self.recaps = fetched
            if let storage, !fetched.isEmpty {
                for item in fetched.reversed() {
                    storage.saveRecap(item)
                }
            }
        } catch {
            self.errorMessage = error.localizedDescription
            if recaps.isEmpty, let storage {
                self.recaps = storage.loadRecaps()
            }
        }
        isLoading = false
    }

    func reload() {
        if let storage {
            recaps = storage.loadRecaps()
        }
    }
}

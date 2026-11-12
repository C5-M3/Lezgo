//
//  MapViewModel+SiriSearch.swift
//  Lezgo
//
//  Created by Nathan Sudiara on 12/11/26.
//

import Foundation

extension MapViewModel {
    /// Set Route opened by "Create a trip" from Siri (US-08): the destination search opens already showing the place
    /// that was said, so the person only picks the right result.
    func onAppear(searchingFor destination: String?) {
        onAppear()
        guard let destination, activeSelectionSheet == .destination(index: 0) else { return }
        searchQuery = destination
        onSearchQueryChanged(destination)
    }
}

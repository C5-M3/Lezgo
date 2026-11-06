//
//  SetRouteMapView.swift
//  Lezgo
//
//  Created by Farrell Sudjatmiko on 26/10/26.
//

import SwiftUI

/// Wrapper forwarding to `SetRouteView` for backwards compatibility with `EditRouteView` and launch arguments.
struct SetRouteMapView: View {
    @State private var viewModel: MapViewModel
    private let title: LocalizedStringResource
    private let nextTitle: LocalizedStringResource
    private let onBack: (() -> Void)?
    private let onNext: (() -> Void)?
    private let onDismiss: (() -> Void)?
    private let onTripCreated: ((TripSession) -> Void)?
    private let isBackDisabled: Bool
    private let isNextDisabled: Bool
    private let isStartPointLocked: Bool

    init(
        viewModel: MapViewModel = MapViewModel(),
        title: LocalizedStringResource = "Plan the route",
        nextTitle: LocalizedStringResource = "Save",
        onBack: (() -> Void)? = nil,
        onNext: (() -> Void)? = nil,
        onDismiss: (() -> Void)? = nil,
        onTripCreated: ((TripSession) -> Void)? = nil,
        isBackDisabled: Bool = false,
        isNextDisabled: Bool = false,
        isStartPointLocked: Bool = false
    ) {
        _viewModel = State(initialValue: viewModel)
        self.title = title
        self.nextTitle = nextTitle
        self.onBack = onBack
        self.onNext = onNext
        self.onDismiss = onDismiss
        self.onTripCreated = onTripCreated
        self.isBackDisabled = isBackDisabled
        self.isNextDisabled = isNextDisabled
        self.isStartPointLocked = isStartPointLocked
    }

    var body: some View {
        SetRouteView(
            viewModel: viewModel,
            title: title,
            saveTitle: nextTitle,
            onBack: onBack,
            onNext: onNext,
            onDismiss: onDismiss,
            isBackDisabled: isBackDisabled,
            isNextDisabled: isNextDisabled,
            isStartPointLocked: isStartPointLocked
        )
    }
}

#Preview {
    SetRouteMapView()
}

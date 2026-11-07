//
//  CarPlaySceneDelegate.swift
//  Lezgo
//
//  Created by Nathan Sudiara on 07/11/26.
//

import CarPlay
import SwiftUI

/// Starts Lezgo on a CarPlay screen (ADR 0023). `Info.plist` names this class for the CarPlay scene.
///
/// The map is the base view, drawn in the window CarPlay gives us; everything on top of it is a template. Both read
/// the trip map open on the phone through `ActiveTripMap.shared`.
final class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {
    /// Kept for as long as CarPlay is connected, as the CarPlay Developer Guide asks.
    private var interfaceController: CPInterfaceController?
    private var carWindow: CPWindow?
    private var tripMapTemplate: CarPlayTripMapTemplate?

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didConnect interfaceController: CPInterfaceController,
        to window: CPWindow
    ) {
        let activeTripMap = ActiveTripMap.shared
        self.interfaceController = interfaceController
        carWindow = window
        window.rootViewController = UIHostingController(rootView: CarPlayMapView(activeTripMap: activeTripMap))

        let tripMapTemplate = CarPlayTripMapTemplate(
            viewModel: CarPlayTripViewModel(activeTripMap: activeTripMap),
            interfaceController: interfaceController
        )
        self.tripMapTemplate = tripMapTemplate
        interfaceController.setRootTemplate(tripMapTemplate.mapTemplate, animated: false, completion: nil)
    }

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didDisconnect interfaceController: CPInterfaceController,
        from window: CPWindow
    ) {
        tripMapTemplate = nil
        carWindow = nil
        self.interfaceController = nil
    }
}

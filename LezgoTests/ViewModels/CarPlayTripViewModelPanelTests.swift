//
//  CarPlayTripViewModelPanelTests.swift
//  LezgoTests
//
//  Created by Nathan Sudiara on 09/11/26.
//

import Foundation
import Testing
@testable import Lezgo

/// The map panel CarPlay shows in place of the phone's cards (ADR 0023, #257).
struct CarPlayTripViewModelPanelTests {
    private typealias Fixtures = TripMapFixtures

    @Test func WithoutATripThePanelSaysSo() {
        let viewModel = CarPlayTripViewModel(activeTripMap: ActiveTripMap())

        #expect(viewModel.panel == .noTrip)
    }

    @Test func LoadingTripHasNoPanel() {
        let activeTripMap = ActiveTripMap()
        activeTripMap.Show(Fixtures.TripMap(states: []))

        let viewModel = CarPlayTripViewModel(activeTripMap: activeTripMap)

        #expect(viewModel.panel == nil)
    }

    @Test func OnTheWayTheMapHasNoPanel() async {
        let viewModel = await Fixtures.CarPlay(mirroring: Fixtures.TripMap(states: [Fixtures.State()]))

        #expect(viewModel.panel == nil)
    }

    @Test func CarsButtonOpensTheCars() async {
        let viewModel = await Fixtures.CarPlay(mirroring: Fixtures.TripMap(states: [Fixtures.State()]))

        viewModel.ShowCars()

        #expect(viewModel.panel == .cars(viewModel.cars))
    }

    @Test func PickedCarReplacesTheCars() async throws {
        let viewModel = await Fixtures.CarPlay(mirroring: Fixtures.TripMap(states: [Fixtures.State()]))
        viewModel.ShowCars()

        viewModel.SelectCar(Fixtures.citraID)

        #expect(viewModel.panel == .car(try #require(viewModel.selectedCar)))
    }

    @Test func ClosingTheCarsLeavesTheMap() async {
        let viewModel = await Fixtures.CarPlay(mirroring: Fixtures.TripMap(states: [Fixtures.State()]))
        viewModel.ShowCars()

        viewModel.ClosePanel(.cars(viewModel.cars))

        #expect(viewModel.panel == nil)
    }

    @Test func ClosingTheCarGoesBackToMyCar() async throws {
        let tripMap = Fixtures.TripMap(states: [Fixtures.State()])
        let viewModel = await Fixtures.CarPlay(mirroring: tripMap)
        viewModel.SelectCar(Fixtures.citraID)

        viewModel.ClosePanel(try #require(viewModel.panel))

        #expect(viewModel.panel == nil)
        #expect(tripMap.cameraMode == .followMyCar)
    }

    @Test func ArrivedCarSeesTheArrival() async throws {
        let tripMap = Fixtures.TripMap(states: [Fixtures.ArrivedState(citraMetres: 500)])
        let viewModel = await Fixtures.CarPlay(mirroring: tripMap)

        #expect(viewModel.panel == .arrival(try #require(viewModel.arrival)))
    }

    @Test func CarsComeBeforeTheArrival() async {
        let tripMap = Fixtures.TripMap(states: [Fixtures.ArrivedState(citraMetres: 500)])
        let viewModel = await Fixtures.CarPlay(mirroring: tripMap)

        viewModel.ShowCars()

        #expect(viewModel.panel == .cars(viewModel.cars))
    }

    @Test func NextTripStartsWithTheCarsClosed() async {
        let activeTripMap = ActiveTripMap()
        let first = Fixtures.TripMap(states: [Fixtures.State()])
        let viewModel = await Fixtures.CarPlay(mirroring: first, on: activeTripMap)
        viewModel.ShowCars()
        activeTripMap.Hide(first)

        let next = Fixtures.TripMap(states: [Fixtures.State()])
        activeTripMap.Show(next)
        await next.Start()

        #expect(viewModel.panel == nil)
    }

    /// Panels of one kind are updated in place, so the list does not flicker when a car moves.
    @Test func SameKindOfPanel() {
        let car = CarPlayTripViewModel.Car(
            id: Fixtures.citraID, name: "Citra", isLeader: false, isMe: false, carColor: .blue
        )
        let arrival = CarPlayTripViewModel.Arrival(title: "A", subtitle: nil, count: "1/3")

        #expect(CarPlayTripViewModel.Panel.cars([]).IsSameKind(as: .cars([car])))
        #expect(CarPlayTripViewModel.Panel.arrival(arrival).IsSameKind(as: .cars([])) == false)
    }
}

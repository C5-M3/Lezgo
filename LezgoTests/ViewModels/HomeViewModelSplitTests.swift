//
//  HomeViewModelSplitTests.swift
//  LezgoTests
//
//  Created by Nathan Sudiara on 16/11/26.
//

import Testing
@testable import Lezgo

/// Which steps the split-screen Home plays for LEAD, JOIN and Back, and when Set Route or Enter room code is on
/// screen (issue #329).
@MainActor
struct HomeViewModelSplitTests {
    private typealias Motion = HomeSplitMotion
    private typealias Step = HomeSplitMotion.Step

    private func MakeViewModel() -> HomeViewModel {
        HomeViewModel(
            mapService: MockMapService(),
            searchService: MockLocationSearchService(),
            activeTripStorage: FakeActiveTripStorage(),
            profileStorage: FakeProfileStorage()
        )
    }

    /// Plays the steps the way the view does, without animation.
    private func Play(_ steps: [Step], on viewModel: HomeViewModel) {
        for step in steps {
            viewModel.BeginSplitStep(step)
            viewModel.FinishSplitStep(step)
        }
        viewModel.FinishSplitMotion()
    }

    @Test func HomeOpensOnTheLeadHome() {
        let viewModel = MakeViewModel()

        #expect(viewModel.splitFlow == .lead)
        #expect(viewModel.splitProgress == 0)
        #expect(viewModel.splitDestination == nil)
    }

    @Test func LeadFillsWithYellowThenRevealsSetRoute() {
        let viewModel = MakeViewModel()

        #expect(viewModel.LeadTapped() == [
            Step(flow: .lead, target: Motion.RevealStart(of: .lead)),
            Step(flow: .lead, target: 1)
        ])
    }

    @Test func JoinFillsWithYellowThenRevealsRoomCode() {
        let viewModel = MakeViewModel()

        #expect(viewModel.JoinTapped() == [
            Step(flow: .join, target: Motion.RevealStart(of: .join)),
            Step(flow: .join, target: 1)
        ])
    }

    @Test func BackFromSetRouteReturnsToTheLeadHome() {
        let viewModel = MakeViewModel()
        Play(viewModel.LeadTapped(), on: viewModel)

        let steps = viewModel.BackTapped()
        Play(steps, on: viewModel)

        #expect(steps == [Step(flow: .lead, target: Motion.RevealStart(of: .lead)), Step(flow: .lead, target: 0)])
        #expect(viewModel.splitProgress == 0)
        #expect(viewModel.splitDestination == nil)
    }

    @Test func BackFromRoomCodeStopsOnTheJoinHome() {
        let viewModel = MakeViewModel()
        Play(viewModel.JoinTapped(), on: viewModel)

        let steps = viewModel.BackTapped()
        Play(steps, on: viewModel)

        #expect(steps == [
            Step(flow: .join, target: Motion.RevealStart(of: .join)),
            Step(flow: .join, target: Motion.joinHome)
        ])
        #expect(viewModel.splitProgress == Motion.joinHome)
        #expect(viewModel.splitDestination == nil)
    }

    @Test func JoinOnTheJoinHomeGoesStraightToRoomCode() {
        let viewModel = MakeViewModel()
        Play(viewModel.JoinTapped(), on: viewModel)
        Play(viewModel.BackTapped(), on: viewModel)

        #expect(viewModel.JoinTapped() == [
            Step(flow: .join, target: Motion.RevealStart(of: .join)),
            Step(flow: .join, target: 1)
        ])
    }

    @Test func LeadOnTheJoinHomeFlipsBackFirst() {
        let viewModel = MakeViewModel()
        Play(viewModel.JoinTapped(), on: viewModel)
        Play(viewModel.BackTapped(), on: viewModel)

        #expect(viewModel.LeadTapped() == [
            Step(flow: .join, target: 0),
            Step(flow: .lead, target: Motion.RevealStart(of: .lead)),
            Step(flow: .lead, target: 1)
        ])
    }

    @Test func TheDestinationStaysOnScreenWhileItWipesAway() {
        let viewModel = MakeViewModel()
        Play(viewModel.LeadTapped(), on: viewModel)
        #expect(viewModel.splitDestination == .lead)

        let back = Step(flow: .lead, target: Motion.RevealStart(of: .lead))
        viewModel.BeginSplitStep(back)
        #expect(viewModel.splitDestination == .lead)

        viewModel.FinishSplitStep(back)
        #expect(viewModel.splitDestination == nil)
    }

    @Test func TapsDuringTheMotionAreIgnored() {
        let viewModel = MakeViewModel()
        let steps = viewModel.LeadTapped()
        viewModel.BeginSplitStep(steps[0])

        #expect(viewModel.LeadTapped().isEmpty)
        #expect(viewModel.JoinTapped().isEmpty)
        #expect(viewModel.BackTapped().isEmpty)
    }

    @Test func BackOnTheHomeDoesNothing() {
        let viewModel = MakeViewModel()

        #expect(viewModel.BackTapped().isEmpty)
    }

    @Test func LinksShowTheirScreenAtOnce() {
        let viewModel = MakeViewModel()

        viewModel.ShowSplitDestination(.join)

        #expect(viewModel.splitFlow == .join)
        #expect(viewModel.splitProgress == 1)
        #expect(viewModel.splitDestination == .join)
    }

    @Test func LeavingForATripResetsToTheLeadHome() {
        let viewModel = MakeViewModel()
        viewModel.ShowSplitDestination(.join)

        viewModel.ResetSplit()

        #expect(viewModel.splitFlow == .lead)
        #expect(viewModel.splitProgress == 0)
        #expect(viewModel.splitDestination == nil)
    }
}

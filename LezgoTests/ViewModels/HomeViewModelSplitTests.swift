//
//  HomeViewModelSplitTests.swift
//  LezgoTests
//
//  Created by Nathan Sudiara on 16/11/26.
//

import Testing
@testable import Lezgo

/// Which runs the split-screen Home plays for LEAD, JOIN and Back, and when Set Route or Enter room code is on
/// screen (issue #329). A tap on the dark half only swings it to yellow; a tap on the yellow half opens its screen.
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

    /// Goes from the LEAD home to the JOIN home with a tap on the dark JOIN half.
    private func GoToTheJoinHome(_ viewModel: HomeViewModel) {
        Play(viewModel.JoinTapped(), on: viewModel)
    }

    @Test func HomeOpensOnTheLeadHome() {
        let viewModel = MakeViewModel()

        #expect(viewModel.splitFlow == .lead)
        #expect(viewModel.splitProgress == 0)
        #expect(viewModel.splitDestination == nil)
    }

    @Test func TheNextScreenIsOnFromTheStartOfTheRun() {
        let viewModel = MakeViewModel()

        viewModel.BeginSplitStep(Step(flow: .lead, target: 1))

        #expect(viewModel.splitDestination == .lead)
        #expect(viewModel.isSplitMoving)
    }

    @Test func TheSwingBackDoesNotShowSetRouteYet() {
        let viewModel = MakeViewModel()
        GoToTheJoinHome(viewModel)

        viewModel.BeginSplitStep(Step(flow: .swingBack, target: 0))

        #expect(viewModel.splitDestination == nil)
    }

    @Test func EachStepRemembersWhereItStarted() {
        let viewModel = MakeViewModel()
        GoToTheJoinHome(viewModel)

        viewModel.BeginSplitStep(Step(flow: .join, target: 1))

        #expect(viewModel.splitStepStart == Motion.joinHome)
    }

    // MARK: - Taps on the halves

    @Test func JoinOnTheLeadHomeOnlySwingsToTheJoinHome() {
        let viewModel = MakeViewModel()

        let steps = viewModel.JoinTapped()
        Play(steps, on: viewModel)

        #expect(steps == [Step(flow: .join, target: Motion.joinHome)])
        #expect(viewModel.splitProgress == Motion.joinHome)
        #expect(viewModel.splitDestination == nil)
    }

    @Test func JoinOnTheJoinHomeGoesToRoomCode() {
        let viewModel = MakeViewModel()
        GoToTheJoinHome(viewModel)

        let steps = viewModel.JoinTapped()
        Play(steps, on: viewModel)

        #expect(steps == [Step(flow: .join, target: 1)])
        #expect(viewModel.splitDestination == .join)
    }

    @Test func LeadOnTheJoinHomeOnlySwingsBack() {
        let viewModel = MakeViewModel()
        GoToTheJoinHome(viewModel)

        let steps = viewModel.LeadTapped()
        Play(steps, on: viewModel)

        #expect(steps == [Step(flow: .swingBack, target: 0)])
        #expect(viewModel.splitProgress == 0)
        #expect(viewModel.splitDestination == nil)
    }

    @Test func LeadOnTheLeadHomeGoesToSetRoute() {
        let viewModel = MakeViewModel()

        #expect(viewModel.LeadTapped() == [Step(flow: .lead, target: 1)])
    }

    @Test func LeadAfterSwingingBackGoesToSetRoute() {
        let viewModel = MakeViewModel()
        GoToTheJoinHome(viewModel)
        Play(viewModel.LeadTapped(), on: viewModel)

        #expect(viewModel.LeadTapped() == [Step(flow: .lead, target: 1)])
        #expect(viewModel.JoinTapped() == [Step(flow: .join, target: Motion.joinHome)])
    }

    @Test func BackFromRoomCodeStopsOnTheJoinHome() {
        let viewModel = MakeViewModel()
        GoToTheJoinHome(viewModel)
        Play(viewModel.JoinTapped(), on: viewModel)

        let steps = viewModel.BackTapped()
        Play(steps, on: viewModel)

        #expect(steps == [Step(flow: .join, target: Motion.joinHome)])
        #expect(viewModel.splitProgress == Motion.joinHome)
        #expect(viewModel.splitDestination == nil)
    }

    @Test func BackFromSetRouteReturnsToTheLeadHome() {
        let viewModel = MakeViewModel()
        Play(viewModel.LeadTapped(), on: viewModel)

        let steps = viewModel.BackTapped()
        Play(steps, on: viewModel)

        #expect(steps == [Step(flow: .lead, target: 0)])
        #expect(viewModel.splitProgress == 0)
        #expect(viewModel.splitDestination == nil)
    }

    // MARK: - Motion in progress

    @Test func TheDestinationStaysOnScreenWhileItWipesAway() {
        let viewModel = MakeViewModel()
        Play(viewModel.LeadTapped(), on: viewModel)
        #expect(viewModel.splitDestination == .lead)

        let back = Step(flow: .lead, target: 0)
        viewModel.BeginSplitStep(back)
        #expect(viewModel.splitDestination == .lead)

        viewModel.FinishSplitStep(back)
        #expect(viewModel.splitDestination == nil)
    }

    @Test func TapsDuringTheMotionAreIgnored() {
        let viewModel = MakeViewModel()
        let steps = viewModel.JoinTapped()
        viewModel.BeginSplitStep(steps[0])

        #expect(viewModel.LeadTapped().isEmpty)
        #expect(viewModel.JoinTapped().isEmpty)
        #expect(viewModel.BackTapped().isEmpty)
    }

    @Test func FastRepeatedTapsOnTheSwingBackAreIgnored() {
        let viewModel = MakeViewModel()
        GoToTheJoinHome(viewModel)
        let steps = viewModel.LeadTapped()
        viewModel.BeginSplitStep(steps[0])
        viewModel.FinishSplitStep(steps[0])

        // Until the view reports the motion finished, the split is still moving.
        #expect(viewModel.LeadTapped().isEmpty)
        #expect(viewModel.JoinTapped().isEmpty)
    }

    @Test func BackOnTheHomeDoesNothing() {
        let viewModel = MakeViewModel()

        #expect(viewModel.BackTapped().isEmpty)
        GoToTheJoinHome(viewModel)
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

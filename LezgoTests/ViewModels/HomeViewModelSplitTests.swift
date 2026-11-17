//
//  HomeViewModelSplitTests.swift
//  LezgoTests
//
//  Created by Nathan Sudiara on 16/11/26.
//

import Testing
@testable import Lezgo

/// Which runs the split-screen Home plays for LEAD, JOIN and Back in both tap styles, and when Set Route or Enter
/// room code is on screen (issue #329).
@MainActor
struct HomeViewModelSplitTests {
    private typealias Motion = HomeSplitMotion
    private typealias Step = HomeSplitMotion.Step

    private func MakeViewModel(_ tapStyle: HomeViewModel.TapStyle = .oneTap) -> HomeViewModel {
        HomeViewModel(
            mapService: MockMapService(),
            searchService: MockLocationSearchService(),
            activeTripStorage: FakeActiveTripStorage(),
            profileStorage: FakeProfileStorage(),
            tapStyle: tapStyle
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

    /// Goes from the LEAD home to the JOIN home the way each tap style does.
    private func GoToTheJoinHome(_ viewModel: HomeViewModel) {
        Play(viewModel.JoinTapped(), on: viewModel)
        if viewModel.splitDestination == .join {
            Play(viewModel.BackTapped(), on: viewModel)
        }
    }

    @Test func HomeOpensOnTheLeadHome() {
        let viewModel = MakeViewModel()

        #expect(viewModel.splitFlow == .lead)
        #expect(viewModel.splitProgress == 0)
        #expect(viewModel.splitDestination == nil)
    }

    @Test func TheTapStyleComesFromTheBuild() {
        #if LEZGO_HOME_TWO_TAP
        #expect(HomeViewModel.TapStyle.build == .twoTap)
        #else
        #expect(HomeViewModel.TapStyle.build == .oneTap)
        #endif
    }

    // MARK: - One tap

    @Test func LeadRunsIntoSetRouteInOneGo() {
        let viewModel = MakeViewModel()

        #expect(viewModel.LeadTapped() == [Step(flow: .lead, target: 1)])
    }

    @Test func JoinSwingsAndRunsIntoRoomCodeInOneGo() {
        let viewModel = MakeViewModel()

        #expect(viewModel.JoinTapped() == [Step(flow: .join, target: 1)])
    }

    @Test func JoinOnTheJoinHomeGoesStraightToRoomCode() {
        let viewModel = MakeViewModel()
        GoToTheJoinHome(viewModel)

        #expect(viewModel.JoinTapped() == [Step(flow: .join, target: 1)])
    }

    @Test func LeadOnTheJoinHomeSwingsBackThenRunsIntoSetRoute() {
        let viewModel = MakeViewModel()
        GoToTheJoinHome(viewModel)

        let steps = viewModel.LeadTapped()
        Play(steps, on: viewModel)

        #expect(steps == [Step(flow: .swingBack, target: 0), Step(flow: .lead, target: 1)])
        #expect(viewModel.splitDestination == .lead)
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

    // MARK: - Two taps

    @Test func TwoTapsJoinOnTheLeadHomeOnlySwingsToTheJoinHome() {
        let viewModel = MakeViewModel(.twoTap)

        let steps = viewModel.JoinTapped()
        Play(steps, on: viewModel)

        #expect(steps == [Step(flow: .join, target: Motion.joinHome)])
        #expect(viewModel.splitProgress == Motion.joinHome)
        #expect(viewModel.splitDestination == nil)
    }

    @Test func TwoTapsJoinOnTheJoinHomeGoesToRoomCode() {
        let viewModel = MakeViewModel(.twoTap)
        GoToTheJoinHome(viewModel)

        let steps = viewModel.JoinTapped()
        Play(steps, on: viewModel)

        #expect(steps == [Step(flow: .join, target: 1)])
        #expect(viewModel.splitDestination == .join)
    }

    @Test func TwoTapsLeadOnTheJoinHomeOnlySwingsBack() {
        let viewModel = MakeViewModel(.twoTap)
        GoToTheJoinHome(viewModel)

        let steps = viewModel.LeadTapped()
        Play(steps, on: viewModel)

        #expect(steps == [Step(flow: .swingBack, target: 0)])
        #expect(viewModel.splitProgress == 0)
        #expect(viewModel.splitDestination == nil)
    }

    @Test func TwoTapsLeadOnTheLeadHomeGoesToSetRoute() {
        let viewModel = MakeViewModel(.twoTap)

        #expect(viewModel.LeadTapped() == [Step(flow: .lead, target: 1)])
    }

    @Test func TwoTapsLeadAfterSwingingBackGoesToSetRoute() {
        let viewModel = MakeViewModel(.twoTap)
        GoToTheJoinHome(viewModel)
        Play(viewModel.LeadTapped(), on: viewModel)

        #expect(viewModel.LeadTapped() == [Step(flow: .lead, target: 1)])
        #expect(viewModel.JoinTapped() == [Step(flow: .join, target: Motion.joinHome)])
    }

    @Test(arguments: [HomeViewModel.TapStyle.oneTap, .twoTap])
    func BackFromRoomCodeStopsOnTheJoinHome(_ tapStyle: HomeViewModel.TapStyle) {
        let viewModel = MakeViewModel(tapStyle)
        GoToTheJoinHome(viewModel)
        Play(viewModel.JoinTapped(), on: viewModel)

        let steps = viewModel.BackTapped()
        Play(steps, on: viewModel)

        #expect(steps == [Step(flow: .join, target: Motion.joinHome)])
        #expect(viewModel.splitProgress == Motion.joinHome)
        #expect(viewModel.splitDestination == nil)
    }

    @Test(arguments: [HomeViewModel.TapStyle.oneTap, .twoTap])
    func BackFromSetRouteReturnsToTheLeadHome(_ tapStyle: HomeViewModel.TapStyle) {
        let viewModel = MakeViewModel(tapStyle)
        Play(viewModel.LeadTapped(), on: viewModel)

        let steps = viewModel.BackTapped()
        Play(steps, on: viewModel)

        #expect(steps == [Step(flow: .lead, target: 0)])
        #expect(viewModel.splitProgress == 0)
        #expect(viewModel.splitDestination == nil)
    }

    // MARK: - Both styles

    @Test(arguments: [HomeViewModel.TapStyle.oneTap, .twoTap])
    func TheDestinationStaysOnScreenWhileItWipesAway(_ tapStyle: HomeViewModel.TapStyle) {
        let viewModel = MakeViewModel(tapStyle)
        Play(viewModel.LeadTapped(), on: viewModel)
        #expect(viewModel.splitDestination == .lead)

        let back = Step(flow: .lead, target: 0)
        viewModel.BeginSplitStep(back)
        #expect(viewModel.splitDestination == .lead)

        viewModel.FinishSplitStep(back)
        #expect(viewModel.splitDestination == nil)
    }

    @Test(arguments: [HomeViewModel.TapStyle.oneTap, .twoTap])
    func TapsDuringTheMotionAreIgnored(_ tapStyle: HomeViewModel.TapStyle) {
        let viewModel = MakeViewModel(tapStyle)
        let steps = viewModel.JoinTapped()
        viewModel.BeginSplitStep(steps[0])

        #expect(viewModel.LeadTapped().isEmpty)
        #expect(viewModel.JoinTapped().isEmpty)
        #expect(viewModel.BackTapped().isEmpty)
    }

    @Test(arguments: [HomeViewModel.TapStyle.oneTap, .twoTap])
    func FastRepeatedTapsOnTheSwingBackAreIgnored(_ tapStyle: HomeViewModel.TapStyle) {
        let viewModel = MakeViewModel(tapStyle)
        GoToTheJoinHome(viewModel)
        let steps = viewModel.LeadTapped()
        viewModel.BeginSplitStep(steps[0])
        viewModel.FinishSplitStep(steps[0])

        // Between the swing back and the run into Set Route the motion is still going.
        #expect(viewModel.LeadTapped().isEmpty)
        #expect(viewModel.JoinTapped().isEmpty)
    }

    @Test(arguments: [HomeViewModel.TapStyle.oneTap, .twoTap])
    func BackOnTheHomeDoesNothing(_ tapStyle: HomeViewModel.TapStyle) {
        let viewModel = MakeViewModel(tapStyle)

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

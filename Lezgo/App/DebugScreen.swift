#if DEBUG
import SwiftUI

/// Opens one screen straight away with simulated data, so you can check your screen in the simulator before the
/// screens that lead to it are finished.
///
/// ## Why this exists
///
/// Each developer builds their own screen (AGENTS.md, "Who owns which screen"), and the screens are joined later.
/// Until then, the screen you are building may not be reachable from Home. Do not comment out `ContentView()` in
/// `LezgoApp` to reach it: the change is easy to commit by mistake, AGENTS.md forbids commented-out code, and every
/// developer would edit the same line. Instead, `LezgoApp` asks this enum which screen to open when the app is
/// launched with the argument `-DebugScreen <name>`. Without the argument, the app starts normally.
///
/// Everything here is inside `#if DEBUG`, so release builds (Xcode Cloud, TestFlight, App Store) do not contain it.
///
/// ## How to open a screen
///
/// 1. In Xcode, open Product > Scheme > Edit Scheme…, and click **Duplicate Scheme** at the bottom.
///    Name the copy, for example `Lezgo Debug Screen`, and **untick "Shared"** so the copy stays on your Mac
///    (unshared schemes live in `xcuserdata`, which Git ignores). Never add the argument to the shared `Lezgo`
///    scheme: that file is in Git and is used by everyone and by Xcode Cloud.
/// 2. In the copy, open Run > Arguments > Arguments Passed On Launch, and add `-DebugScreen tripMapLeader`
///    (any name from the list below).
/// 3. Run the copy. To open another screen, change the argument. To start the app normally, untick it or run the
///    shared `Lezgo` scheme.
///
/// From the command line, with the app already installed on a booted simulator:
/// `xcrun simctl launch booted <bundle identifier> -DebugScreen tripMapMember`
///
/// ## Screens you can open
///
/// | Name | Screen | Owner |
/// | --- | --- | --- |
/// | `draftTrip` | Draft Road Trip screen for a member | R |
/// | `draftTripLeader` | Draft Road Trip screen for the leader | R |
/// | `tripMapLeader` | Trip Started map on the leader's phone (Agus), with a simulated drive | N |
/// | `tripMapMember` | Trip Started map on a member's phone (Budi), with a simulated drive | N |
/// | `syncCheck` | Sync Check: create, join and hand over a trip through real iCloud, to test sync between phones | N |
///
/// ## How to add your screen
///
/// 1. Add a case named after your screen and its variant, for example `case tripRoomLeader`. The case name is the
///    name you pass after `-DebugScreen`.
/// 2. Return your screen in `MakeView()`, built with simulated or mock data. Keep that data in your own
///    `Simulated…` type inside `#if DEBUG` next to your screen's code, not in this file.
/// 3. Add a row to the table above. Keep the cases in the order of the app flow, so merges stay simple.
/// 4. Add a test for your case to `LezgoTests/App/DebugScreenTests.swift`.
///
/// Remove a case when its simulated data is deleted. Keep the enum while it still helps to open a screen directly
/// for UI checks.
enum DebugScreen: String, CaseIterable {
    case draftTrip
    case draftTripLeader
    case tripMapLeader
    case tripMapMember
    case syncCheck

    /// The launch argument that names the screen, followed by the screen's name.
    static let launchArgument = "-DebugScreen"

    /// The screen named after `-DebugScreen` in the launch arguments, or `nil` to start the app normally.
    ///
    /// An unknown name also returns `nil`, so a typo starts the normal app instead of crashing it.
    static func FromLaunchArguments(_ arguments: [String] = ProcessInfo.processInfo.arguments) -> DebugScreen? {
        guard let flagIndex = arguments.firstIndex(of: launchArgument), flagIndex + 1 < arguments.count else {
            return nil
        }
        return DebugScreen(rawValue: arguments[flagIndex + 1])
    }

    /// The screen to show instead of the normal first screen.
    @ViewBuilder
    func MakeView() -> some View {
        switch self {
        case .draftTrip:
            DraftTripView.Simulated(isLeader: false)
        case .draftTripLeader:
            DraftTripView.Simulated(isLeader: true)
        case .tripMapLeader:
            TripMapView.Simulated(myParticipantID: SimulatedTripMapDrive.agusID)
        case .tripMapMember:
            TripMapView.Simulated(myParticipantID: SimulatedTripMapDrive.budiID)
        case .syncCheck:
            SyncCheckView()
        }
    }
}
#endif

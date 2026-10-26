#if DEBUG
import Testing
@testable import Lezgo

struct DebugScreenTests {
    private static let appPath = "/path/to/Lezgo.app/Lezgo"

    @Test(arguments: DebugScreen.allCases)
    func ArgumentOpensTheNamedScreen(screen: DebugScreen) {
        let arguments = [Self.appPath, "-DebugScreen", screen.rawValue]

        #expect(DebugScreen.FromLaunchArguments(arguments) == screen)
    }

    @Test func AppStartsNormallyWithoutTheArgument() {
        #expect(DebugScreen.FromLaunchArguments([Self.appPath]) == nil)
    }

    @Test func UnknownScreenNameStartsTheAppNormally() {
        let arguments = [Self.appPath, "-DebugScreen", "tripMapLeadr"]

        #expect(DebugScreen.FromLaunchArguments(arguments) == nil)
    }

    @Test func ArgumentWithoutANameStartsTheAppNormally() {
        #expect(DebugScreen.FromLaunchArguments([Self.appPath, "-DebugScreen"]) == nil)
    }

    @Test func OtherLaunchArgumentsAreIgnored() {
        let arguments = [Self.appPath, "-AppleLanguages", "(en)", "-DebugScreen", "tripMapMember", "-Verbose"]

        #expect(DebugScreen.FromLaunchArguments(arguments) == .tripMapMember)
    }

    @Test func ScreenNameIsCaseSensitive() {
        let arguments = [Self.appPath, "-DebugScreen", "TripMapMember"]

        #expect(DebugScreen.FromLaunchArguments(arguments) == nil)
    }
}
#endif

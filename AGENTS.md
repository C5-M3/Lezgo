# AGENTS.md

Shared rules for every AI agent (Claude Code, Codex, Cursor, Gemini, Xcode) and every human working on Lezgo.
Work like a senior iOS engineer: small, tested, readable changes that follow Apple's Human Interface Guidelines and App Review Guidelines.
If a rule here conflicts with a skill or your own defaults, this file wins.


## Project context

- **Challenge statement:** Make group road trips feel together.
- **App statement:** An app that helps a group of cars stay coordinated during casual trips by sharing a dynamic route guided by a lead driver.

How the app works:

- One car is one person with one phone: only one person per car joins. There are only two roles: one **Leader** per trip (the lead car) and **Members** (everyone else). A member driving alone is still just a member.
- The Leader plans the route (start point, 0 or more checkpoints, destination) and opens a **Trip Room**. Members join with a 6-digit room code (numbers only) or an invite link.
- In the Trip Room the group reviews the route and the participant list. The Leader can remove participants, hand over the lead and start the trip.
- During the trip everyone sees the shared route and every car on the map. Tapping a car shows its driver, status, street and ETA. Members get silent visual alerts when they leave the route, pass a checkpoint, or drive ahead of the Leader.
- If the Leader leaves the route, the route is recalculated for everyone. The Leader can edit the route, pick a New Destination on arrival, or End Trip; Members can Exit Trip on their own. When the Leader leaves, the trip ends for everyone (with a warning); to leave without ending it, the Leader hands over the lead first.
- Safety first: the driver must not be distracted. Alerts are visual, controls are large, and destructive actions ask for confirmation.

Each task's lo-fi screens, acceptance criteria, TDD steps and Definition of Done are in its GitHub issue. Read the issue before you start.


## Project snapshot

| Item | Value |
| --- | --- |
| Platform | iOS 27.0+, Xcode 27.1 |
| UI | SwiftUI (no UIKit unless asked) |
| Persistence | SwiftData |
| Concurrency | Default actor isolation `MainActor`, approachable concurrency on |
| Strings | String Catalog (`Localizable.xcstrings`) with generated symbols |
| Architecture | MVVM, layer-first folders |
| Tests | Swift Testing for unit tests, XCTest only for UI tests |
| Remote | `github.com/C5-M3/Lezgo`, tasks live in the GitHub Project "Project Management" (#1, org `C5-M3`) |

Do not add third-party dependencies without asking first.


## Architecture decisions

Past decisions and their reasons are recorded in [`docs/adr/`](docs/adr/README.md) as architecture decision records (ADRs). AGENTS.md holds the rules; the ADRs hold why.

- Read the [ADR index](docs/adr/README.md) before starting a task. Do not work against an Accepted record, and do not reopen a settled question without a reason.
- If a task needs a different decision, stop and write a new ADR from `docs/adr/Template.md` with status Proposed. Ask the user to approve it before writing code.
- Write an ADR when you add a dependency or framework, change the architecture or folder layout, go against Apple's conventions, change the workflow or CI, or make any choice that is hard to undo.
- Never rewrite an accepted ADR. A new ADR supersedes it, and the old one's status becomes `Superseded by NNNN`.


## Branches

Decision record: [0005](docs/adr/0005-TrunkBranchesAndConventionalBranch.md).

| Branch | Purpose | Who merges into it |
| --- | --- | --- |
| `main` | Production / App Store. The last stop. | Release PR from `staging` |
| `staging` | External TestFlight builds | PR from `dev` when a feature needs TestFlight testing |
| `dev` | Integration and quick developer testing | Feature PRs, after review |
| `<type>/<description>` | One issue's work | Nobody; it is merged and then deleted |

Feature branches follow [Conventional Branch](https://conventionalbranch.org): lowercase, words joined by hyphens, issue number included.

| Type | Use for | Example |
| --- | --- | --- |
| `feature/` | New functionality | `feature/issue-12-add-login-screen` |
| `bugfix/` | Non-urgent fix | `bugfix/issue-31-fix-empty-list-crash` |
| `hotfix/` | Urgent fix for `main` | `hotfix/issue-40-patch-token-leak` |
| `release/` | Release preparation | `release/v1.2.0` |
| `chore/` | Tooling, docs, dependencies | `chore/issue-7-add-swiftlint` |

Never push directly to `main`, `staging` or `dev`. Never merge your own PR.


## Workflow for every task

Decision record: [0007](docs/adr/0007-IssueBranchPullRequestWorkflow.md).

1. **Find the issue.** Tasks start as draft items in the [GitHub Project](https://github.com/orgs/C5-M3/projects/1). If the task is still a draft, convert it to an issue in `C5-M3/Lezgo` (in the web UI: open the draft, then "Convert to issue"). If it is not in the project at all, create the issue and add it:
   ```bash
   gh issue create --repo C5-M3/Lezgo --title "<short title>" --body "<what and why>"
   gh project item-add 1 --owner C5-M3 --url <issue-url>
   ```
   Move the item to "In Progress" in the project when you start.
2. **Start from a fresh `dev`** and create the branch from the issue, so GitHub links them (same as "Create a branch" under "Development" on the issue page):
   ```bash
   git switch dev
   git pull origin dev
   gh issue develop <number> --base dev --name feature/issue-<number>-<short-description> --checkout
   ```
   While working, keep the branch current with `git pull --rebase origin dev`, resolve any conflicts, then `git push --force-with-lease`. Never force-push a trunk branch.
3. **Look for existing code and decisions before writing new code** (see [Reuse before you build](#reuse-before-you-build) and [Architecture decisions](#architecture-decisions)).
4. **Write the failing test first**, then the code (see [Test-driven development](#test-driven-development)).
5. **Commit and push every small step.** One logical change per commit. Do not save work up for one big commit.
6. **Check the UI and the edge cases** in the simulator (see [UI checks after coding](#ui-checks-after-coding)).
7. **Open a PR into `dev`**, filled in from `.github/pull_request_template.md`, and link the issue (`Closes #<number>`):
   ```bash
   gh pr create --base dev --title "<conventional commit style title>" --body-file <filled-in-template.md>
   ```
8. **Wait for review.** Address comments with new commits. Do not merge until a reviewer approves.
9. **After the merge, delete the branch** locally and on the remote:
   ```bash
   git switch dev && git pull origin dev
   git branch -d feature/issue-<number>-<short-description>
   git push origin --delete feature/issue-<number>-<short-description>
   ```


## Continuous integration

Decision record: [0011](docs/adr/0011-XcodeCloudAndGitHubActions.md).

Xcode Cloud builds the app and ships TestFlight. GitHub Actions only guards the source:

| Workflow | Runs on | Checks |
| --- | --- | --- |
| `Security Checks` | Every PR, pushes to `main`, `staging`, `dev` | XCSSET malware signs in Xcode projects (`Scripts/ScanForXcsset.sh`), secrets in git history (Gitleaks) |
| `Pull Request Checks` | Every PR | Branch name, branch flow, PR title and commit messages (`Scripts/CheckPullRequestRules.sh`), ADR format and index (`Scripts/CheckDecisionRecords.sh`) |
| `SwiftLint` | Every PR, pushes to `main`, `staging`, `dev` | `.swiftlint.yml` rules in strict mode: any warning fails |

Run the same checks locally before opening a PR:

```bash
Scripts/ScanForXcsset.sh .
Scripts/CheckDecisionRecords.sh
git log --format=%s origin/dev..HEAD | Scripts/CheckPullRequestRules.sh "$(git branch --show-current)" dev "<PR title>"
```

Never add a build script phase, scheme pre/post action or build rule without explaining it in the PR. The scanner warns on each one so a reviewer reads it. Pin every third-party GitHub Action to a full commit SHA, and give workflows read-only permissions unless a job needs more.


## Commits

Decision record: [0006](docs/adr/0006-ConventionalCommits.md).

Use [Conventional Commits](https://www.conventionalcommits.org): `<type>(<optional scope>): <summary>`.

- Types (see `README.md` for what each means): `feat`, `fix`, `refactor`, `perf`, `style`, `test`, `docs`, `build`, `ci`, `ops`, `chore`.
- Summary in the imperative, lowercase, no trailing period, at most 72 characters.
- Examples: `test(login): add failing test for empty email`, `feat(login): validate email format`, `refactor(components): extract PrimaryButton`.
- In TDD, the test commit and the implementation commit are separate.
- Every commit must build. Run the tests before you push.


## Reuse before you build

Before writing any view, model, helper or extension:

1. Search the codebase for the same or a similar feature (`grep` for the concept, browse `Views/Components/`, `Extensions/`, `Services/`).
2. If it exists as a reusable component, use it.
3. If similar code exists inline in a screen, extract it into a reusable component first (in its own commit), replace the original, then use it in your feature.
4. Only create something new when nothing similar exists.

A shared component must be used in at least two places. Code used in only one place stays local to its screen until a second user appears.


## Architecture: MVVM, layer first

Decision record: [0003](docs/adr/0003-MvvmLayerFirst.md).

Folders are grouped by layer, not by feature. The project uses Xcode synchronized folders, so new files and folders on disk appear in Xcode automatically. Git does not track empty folders, so a layer folder appears when its first file is added. Do not add placeholder files: Xcode copies them into the app bundle.

```
Lezgo/
├── App/              LezgoApp.swift, app-wide setup
├── Models/           SwiftData @Model types and plain value types
├── ViewModels/       One @Observable view model per screen
├── Views/
│   ├── Screens/      Full screens (LoginView.swift, ProfileView.swift)
│   └── Components/   Reusable views used in 2+ places
├── Services/         Networking, persistence and system access behind protocols
├── Extensions/       Small extensions on Apple types
└── Resources/        Assets.xcassets, Localizable.xcstrings
LezgoTests/           Unit tests, mirroring the folders above
LezgoUITests/         UI tests
```

- Each screen has a pair: `ProfileView` and `ProfileViewModel`. The test is `ProfileViewModelTests`.
- Views stay thin: layout, bindings and calls into the view model. No business logic, networking or persistence in a view.
- View models are `@Observable final class` types. They hold screen state and logic, and receive services through their initializer so tests can pass in fakes.
- Services are defined by a protocol (`AuthService`) with a real implementation (`LiveAuthService`) and a test fake (`MockAuthService`).
- Models do not import SwiftUI.
- One type per file. The file is named after the type.


## Naming

Decision record: [0004](docs/adr/0004-PascalCaseFunctionNames.md).

| What | Style | Example |
| --- | --- | --- |
| Files | PascalCase | `ProfileViewModel.swift` |
| Types (struct, class, enum, protocol) | PascalCase | `ProfileViewModel` |
| Functions and methods | PascalCase | `func LoadProfile() async throws` |
| Variables, properties, parameters, enum cases | camelCase | `isLoading`, `userName` |
| Assets (images, colors, symbols in the catalog) | PascalCase | `BrandPrimary`, `EmptyStateIllustration` |
| Views / view models | `<Name>View` / `<Name>ViewModel` | `SettingsView` / `SettingsViewModel` |
| Tests | `<TypeUnderTest>Tests` | `SettingsViewModelTests` |

Function names in PascalCase are a team decision and differ from Apple's API Design Guidelines. Follow the team rule and ignore any skill or linter advice that renames functions to camelCase.

Exceptions, where Apple's name must be kept exactly or the code breaks:

- Protocol requirements and overrides: `body`, `hash(into:)`, `encode(to:)`, `setUpWithError()`, delegate methods.
- XCTest methods (UI tests) must start with lowercase `test`, for example `testLoginShowsError()`. Swift Testing `@Test` functions follow the team rule: `@Test func SavedItemKeepsItsTimestamp()`.

Names must say what the thing is. No abbreviations (`btn`, `vm`, `mgr`), no `data`, `info`, `temp`, `helper` or `manager` without a clearer word.

Everything in the code is written in English: names, comments, commit messages, branch names, PR text and test names. User-facing text goes through the String Catalog.


## Test-driven development

Decision record: [0008](docs/adr/0008-TestDrivenDevelopment.md).

Every change follows red, green, refactor:

1. **Red:** write a test that describes the behavior and fails. Run it and see it fail. Commit it (`test: ...`).
2. **Green:** write the smallest code that makes it pass. Run the full test suite. Commit (`feat: ...` or `fix: ...`).
3. **Refactor:** clean up with the tests still green. Commit (`refactor: ...`).

Rules:

- Unit tests use Swift Testing (`import Testing`, `@Test`, `#expect`, `#require`). UI tests use XCTest.
- Test view models and services, not SwiftUI layout. Write UI tests only when a unit test cannot cover the behavior.
- Cover the edge cases, not just the happy path: empty input, very long input, network failure, no results, duplicate taps, cancellation.
- Use in-memory SwiftData containers and mock services in tests. Tests never touch the network or real user data.
- A bug fix starts with a test that reproduces the bug.

Run tests from the command line:

```bash
xcodebuild test -project Lezgo.xcodeproj -scheme Lezgo -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=27.0'
```

Unit tests go in `LezgoTests/`, mirroring the app folder of the code under test (`LezgoTests/ViewModels/ProfileViewModelTests.swift`). UI tests go in `LezgoUITests/`. The shared `Lezgo` scheme runs both. If no iOS 27 simulator exists, create one in Xcode (Window > Devices and Simulators).


## Swift and SwiftUI rules

Swift:

- Use `async`/`await` over completion handlers. Never use `DispatchQueue`. Use `Task.sleep(for:)`.
- No force unwraps (`!`) or `try!` unless the failure is truly impossible, and leave a comment saying why.
- Use `FormatStyle` (`date.formatted(...)`, `value.formatted(.number)`), never `DateFormatter`, `NumberFormatter` or `String(format:)`.
- Filter user text with `localizedStandardContains()`.
- Prefer value types. Mark classes `final` unless they are designed for subclassing.
- Handle errors where they can be handled; show the user a clear message, never a silent failure.

SwiftUI:

- Use `@Observable` with `@State`, `@Bindable` and `@Environment`. Do not use `ObservableObject`, `@Published`, `@StateObject` or `@EnvironmentObject`.
- Use `NavigationStack` with `navigationDestination(for:)`, the `Tab` API, `foregroundStyle()` and `clipShape(.rect(cornerRadius:))`.
- Use `Button` for taps. Use `onTapGesture` only when you need the tap location or count.
- Split large views into new `View` structs, not computed properties that return views.
- Avoid `AnyView`, `GeometryReader` (when `containerRelativeFrame` or `visualEffect` works) and `UIScreen.main.bounds`.
- Icon buttons always have text: `Button("Add item", systemImage: "plus", action: AddItem)`.
- Add a `#Preview` for every view and component, including an empty state and a large Dynamic Type size where relevant.

Clean code:

- Small functions that do one thing. Early returns over nested `if`.
- No dead code, commented-out code, `print` debugging or `TODO` without an issue number.
- Comments explain why, not what. Add `///` doc comments to public types and non-obvious functions.
- Do not write filler: no placeholder views, no speculative abstractions, no code "for later".
- `swiftlint lint --strict` must pass before you commit (`brew install swiftlint`). The rules live in `.swiftlint.yml`; change them there, never with `swiftlint:disable` comments unless the PR explains why.


## UI consistency

- Use the shared components in `Views/Components/` and the colors in `Assets.xcassets`. Do not hard-code colors, fonts or one-off styles in screens.
- Use system text styles (`.font(.body)`, `.font(.headline)`) and system spacing. Avoid fixed padding and stack spacing unless the design asks for it.
- Same element, same look, everywhere: buttons, cards, empty states, loading states and error states share one component each.
- Follow the Human Interface Guidelines for layout, navigation and controls.


## UI checks after coding

After any UI change, build and run the app in the simulator and check, before opening the PR:

- The happy path works end to end.
- Empty, loading and error states look right.
- Very long text, missing data and fast repeated taps do not break the layout.
- Light and dark mode.
- The largest accessibility text size (Accessibility XXXL) and the smallest size.
- Portrait and landscape, and a small screen (iPhone 17e) as well as a large one (iPhone 17 Pro Max).

Attach screenshots of the changed screens to the PR.


## Accessibility (minimum bar)

Decision record: [0009](docs/adr/0009-AccessibilityMinimumBar.md).

- **Dynamic Type:** text uses text styles and scales. Layouts adapt at large sizes (stack vertically, allow wrapping, use `ViewThatFits`), and nothing is clipped or truncated without a way to read it.
- **Color contrast:** at least 4.5:1 for body text and 3:1 for large text and icons, in light and dark mode. Never use color as the only way to show meaning.
- **VoiceOver:** every control has a clear label (`"Close"`, not `"Close button"`). Decorative images are hidden; meaningful ones have labels. Related elements are grouped.
- **Touch targets:** at least 44x44 points.
- **Reduce Motion:** respect `accessibilityReduceMotion` for non-essential animation.

Check with Xcode's Accessibility Inspector and the Dynamic Type size slider in the simulator.


## Security

Decision record: [0010](docs/adr/0010-SecurityBaseline.md).

- Never commit secrets: API keys, tokens, certificates, `.env` files, `Secrets.swift`, `Secrets.xcconfig`. They are in `.gitignore`; keep it that way. If a secret is committed, tell the user immediately so it can be rotated.
- Store credentials and tokens in the Keychain, never in `UserDefaults`, plists, SwiftData or files.
- Use HTTPS only. Do not add App Transport Security exceptions.
- Validate and sanitize all input from users, the network, deep links and the pasteboard.
- Do not log personal data, tokens or passwords.
- Request the fewest permissions needed, at the moment they are needed, with a clear usage description.
- Use `CryptoKit` for cryptography. Never write your own crypto and never use MD5 or SHA-1 for security.
- Mark sensitive files with data protection, and hide sensitive screens in the app switcher snapshot when needed.


## Explaining your changes

The people on this team are learning from your code. After every task, explain what you changed in plain language:

1. **What** changed, file by file, in one or two sentences each.
2. **Why** it was done this way, and which alternative you rejected.
3. **The key idea** a beginner should take away (for example, "the view model receives the service through its initializer so the test can pass in a fake").

Keep it short and simple. Use small code snippets only when they make the idea clearer.


## Agent skills

Decision record: [0012](docs/adr/0012-PinnedAgentSkills.md).

These skills give agents up-to-date Swift knowledge. They are installed per developer, not committed (`.agents/` and `.claude/` are git-ignored). Install them once after cloning:

```bash
./Scripts/InstallAgentSkills.sh
```

| Skill | Use when | Source |
| --- | --- | --- |
| `swiftui-pro` | Writing or reviewing SwiftUI | [twostraws/SwiftUI-Agent-Skill](https://github.com/twostraws/SwiftUI-Agent-Skill) |
| `swiftdata-pro` | Models, queries, persistence | [twostraws/SwiftData-Agent-Skill](https://github.com/twostraws/SwiftData-Agent-Skill) |
| `swift-concurrency-pro` | `async`/`await`, actors, tasks | [twostraws/Swift-Concurrency-Agent-Skill](https://github.com/twostraws/Swift-Concurrency-Agent-Skill) |
| `swift-testing-pro` | Writing or reviewing tests | [twostraws/Swift-Testing-Agent-Skill](https://github.com/twostraws/Swift-Testing-Agent-Skill) |
| `ios-accessibility` | VoiceOver, Dynamic Type, accessibility audits | [dadederk/iOS-Accessibility-Agent-Skill](https://github.com/dadederk/iOS-Accessibility-Agent-Skill) |
| `swift-security-expert` | Keychain, CryptoKit, credentials, biometrics | [ivan-magda/swift-security-skill](https://github.com/ivan-magda/swift-security-skill) |

Load the matching skill before writing code in its area, and run `swiftui-pro` over your diff before opening a PR.
The script pins each skill to a reviewed commit. To update a skill, read the new version first, then change its commit in the script.

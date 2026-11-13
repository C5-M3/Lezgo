# Lezgo

- **Tasks:** [GitHub Project](https://github.com/orgs/C5-M3/projects/1)
- **Coding rules for humans and AI agents:** [AGENTS.md](AGENTS.md)
- **User stories, data model and copy:** [specs/UserStories.md](specs/UserStories.md)
- **How trip data and iCloud sync work:** [CloudKit/TripSync.md](CloudKit/TripSync.md)
- **Past decisions and why we made them:** [docs/adr](docs/adr/README.md)


## Requirements

- macOS and Xcode 27.1 or later (update both first if an update is available)
- An iOS 18.1 simulator and an iOS 27 simulator (Xcode > Settings > Components). The app supports iOS 18.0 and later, so tests run on both.
- [GitHub CLI](https://cli.github.com) (`brew install gh`), optional but used in the commands below


## Getting started

```bash
git clone https://github.com/C5-M3/Lezgo.git
cd Lezgo
git switch dev
cp Config/Local.xcconfig.example Config/Local.xcconfig
open Lezgo.xcodeproj
```

Edit `Config/Local.xcconfig` and set your own Apple Developer team ID and bundle identifier prefix (see [ADR 0015](docs/adr/0015-PerDeveloperSigningSettings.md)). The file is git-ignored, so your settings never reach a pull request.
The first time you build, open the Lezgo target's Signing & Capabilities tab and make sure the iCloud container `iCloud.<your prefix>.Lezgo` is ticked, so Xcode registers it on your account.

If you work with AI agents (Claude Code, Codex, Cursor), install the shared Swift skills once:

```bash
./Scripts/InstallAgentSkills.sh
```


## Branches

| Branch | Purpose |
| --- | --- |
| `main` | Production / App Store. The last stop, promoted from `staging`. |
| `staging` | External TestFlight builds. Promoted from `dev` when a feature needs testing. |
| `dev` | Development. Feature branches are merged here after review. |
| `<type>/<description>` | One issue's work. Deleted after it is merged. |

Feature work always starts from `dev` and goes back into `dev` through a pull request.


## Workflow

1. Open the [GitHub Project](https://github.com/orgs/C5-M3/projects/1) and pick a draft item to work on.
2. Open the draft and click **Convert to issue**. Choose the `C5-M3/Lezgo` repository.
3. On the new issue, under **Development** in the sidebar, click **Create a branch**. Set the source branch to `dev` and name the branch using the [naming rules](#branch-names).
4. Pull the latest `dev` and check out the branch:
   ```bash
   git switch dev
   git pull origin dev
   git fetch origin
   git switch <branch-name>
   ```
5. Commit and push small changes often, using [Conventional Commits](#commit-messages).
6. When the work is done, open a pull request from your branch into `dev`. Fill in the template and link the issue.
7. Wait for a review. Merge only after approval, then delete the branch.


## Branch names

Branch names follow [Conventional Branch](https://conventionalbranch.org): `<type>/<description>`, in lowercase, with words joined by hyphens. Include the issue number when there is one.

| Type | Use for | Example |
| --- | --- | --- |
| `feature/` | New features | `feature/issue-12-add-login-page` |
| `bugfix/` | Bug fixes | `bugfix/issue-31-fix-header-bug` |
| `hotfix/` | Urgent fixes | `hotfix/security-patch` |
| `release/` | Preparing a release | `release/v1.2.0` |
| `chore/` | Non-code tasks such as dependencies or docs | `chore/update-dependencies` |

The trunk branches `main`, `staging` and `dev` have no prefix.


## Commit messages

Commits follow [Conventional Commits](https://gist.github.com/qoomon/5dfcdf8eec66a051ecd85625518cfd13): `<type>(<optional scope>): <description>`.

```bash
git add <files>
git commit -m "feat(home): add home page"
git push origin <branch-name>
```

| Type | Use for |
| --- | --- |
| `feat` | Adding or removing a feature |
| `fix` | Fixing a bug |
| `refactor` | Restructuring code without changing behavior |
| `perf` | A refactor that improves performance |
| `style` | Formatting only (white space, line breaks) |
| `test` | Adding or correcting tests |
| `docs` | Documentation only |
| `build` | Build tools, dependencies, project version |
| `ci` | CI configuration (`.github/workflows`) |
| `ops` | Infrastructure, deployment, backup, recovery |
| `chore` | Anything else, such as editing `.gitignore` |


## Staying up to date

Pull the latest changes:

```bash
git pull origin <branch-name>
```

Rebase your branch on the latest `dev` before opening a pull request:

```bash
git pull --rebase origin dev
git push --force-with-lease
```

Resolve any conflicts during the rebase. Never force-push `main`, `staging` or `dev`.


## Automated checks

Xcode Cloud builds the app and ships TestFlight. GitHub Actions checks every pull request:

- **Security Checks:** scans Xcode projects for XCSSET malware and the git history for leaked secrets.
- **Pull Request Checks:** checks the branch name, the target branch, the PR title, every commit message and the architecture decision records.

- **SwiftLint:** lints the Swift code in strict mode, so any warning fails.

Run the same checks locally before you open a pull request:

```bash
Scripts/ScanForXcsset.sh .
Scripts/CheckDecisionRecords.sh
git log --format=%s origin/dev..HEAD | Scripts/CheckPullRequestRules.sh "$(git branch --show-current)" dev "<PR title>"
```


## Promoting to staging or main

`dev` goes to `staging` when a feature needs a TestFlight build, and `staging` goes to `main` for a release. The **Promote** workflow does this in one step, with no pull request and no second review: the code was already reviewed on its way into `dev` (see [ADR 0026](docs/adr/0026-ManualPromotionWorkflow.md)). It runs only when someone starts it, never on a push.

On GitHub:

1. Open the **Actions** tab and choose **Promote** in the list on the left.
2. Click **Run workflow**.
3. Pick the target:
   - `staging`: moves `staging` to where `dev` is.
   - `main`: moves `main` to where `staging` is.
   - `staging-and-main`: moves both to where `dev` is.
4. Click **Run workflow**. The run summary says which commit was promoted.

Or from the terminal, on any branch. Each command matches one target above:

```bash
# staging: moves staging to where dev is
gh workflow run Promote --repo C5-M3/Lezgo -f target=staging
```

```bash
# main: moves main to where staging is
gh workflow run Promote --repo C5-M3/Lezgo -f target=main
```

```bash
# staging-and-main: moves both to where dev is
gh workflow run Promote --repo C5-M3/Lezgo -f target=staging-and-main
```

Good to know:

- It promotes the branch as it is on GitHub. Work that is not merged into `dev` yet is not included.
- It only moves the target branch forward (a fast-forward). It never force-pushes, so it cannot delete commits.
- It stops if Secret Scan, XCSSET Malware Scan or SwiftLint did not pass on the commit. Wait for the checks on `dev` to finish, then run it again.
- It stops if the target has commits the source does not have, for example a hotfix on `staging`. Merge `main` into `dev` with a pull request first, then run it again.
- A promotion that includes changes to `.github/workflows` needs a `PROMOTE_TOKEN` repository secret (a token with contents and workflows write access). Ask a repository admin.

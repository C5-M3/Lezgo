# Lezgo

- **Tasks:** [GitHub Project](https://github.com/orgs/C5-M3/projects/1)
- **Coding rules for humans and AI agents:** [AGENTS.md](AGENTS.md)
- **Past decisions and why we made them:** [docs/adr](docs/adr/README.md)


## Requirements

- macOS and Xcode 27.1 or later (update both first if an update is available)
- An iOS 27 simulator (Xcode > Settings > Components)
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

If you work with AI agents (Claude Code, Codex, Cursor), install the shared Swift skills once:

```bash
./Scripts/InstallAgentSkills.sh
```


## Branches

| Branch | Purpose |
| --- | --- |
| `main` | Production / App Store. The last branch anything is merged into. |
| `staging` | External TestFlight builds. Merged from `dev` when a feature needs testing. |
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

Run the same checks locally before you open a pull request:

```bash
Scripts/ScanForXcsset.sh .
Scripts/CheckDecisionRecords.sh
git log --format=%s origin/dev..HEAD | Scripts/CheckPullRequestRules.sh "$(git branch --show-current)" dev "<PR title>"
```

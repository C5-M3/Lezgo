#!/usr/bin/env bash
# Tests for Scripts/CheckPullRequestRules.sh.

set -uo pipefail

repoRoot="$(cd "$(dirname "$0")/../.." && pwd)"
checker="$repoRoot/Scripts/CheckPullRequestRules.sh"
outputFile="$(mktemp)"
trap 'rm -f "$outputFile"' EXIT

passedCount=0
failedCount=0

# ExpectCheck <name> <expected: pass|fail> <head branch> <base branch> <title> [commit subjects...]
ExpectCheck() {
  local name="$1" expected="$2" headBranch="$3" baseBranch="$4" title="$5" actual
  shift 5
  if printf '%s\n' "$@" | "$checker" "$headBranch" "$baseBranch" "$title" > "$outputFile" 2>&1; then
    actual="pass"
  else
    actual="fail"
  fi

  if [[ "$actual" == "$expected" ]]; then
    passedCount=$((passedCount + 1))
    echo "ok   $name"
  else
    failedCount=$((failedCount + 1))
    echo "FAIL $name (expected $expected, got $actual)"
    sed 's/^/     /' "$outputFile"
  fi
}

goodCommits=("test(login): add failing test for empty email" "feat(login): validate email format")

# Branch names
ExpectCheck "feature branch into dev passes" pass "feature/issue-12-add-login" dev "feat: add login" "${goodCommits[@]}"
ExpectCheck "short feat prefix passes" pass "feat/add-login" dev "feat: add login" "${goodCommits[@]}"
ExpectCheck "bugfix branch passes" pass "bugfix/issue-3-fix-crash" dev "fix: crash on empty list" "fix: handle empty list"
ExpectCheck "chore branch passes" pass "chore/issue-21-add-github-workflows" dev "chore: add workflows" "ci: add workflows"
ExpectCheck "unknown prefix fails" fail "feature-login" dev "feat: add login" "${goodCommits[@]}"
ExpectCheck "unsupported type fails" fail "wip/login" dev "feat: add login" "${goodCommits[@]}"
ExpectCheck "uppercase branch fails" fail "feature/Add-Login" dev "feat: add login" "${goodCommits[@]}"
ExpectCheck "underscore branch fails" fail "feature/add_login" dev "feat: add login" "${goodCommits[@]}"
ExpectCheck "trailing hyphen fails" fail "feature/add-login-" dev "feat: add login" "${goodCommits[@]}"
ExpectCheck "release with dots passes" pass "release/v1.2.0" main "chore: release v1.2.0" "chore: bump version to 1.2.0"
ExpectCheck "release with trailing dot fails" fail "release/v1.2.0." main "chore: release v1.2.0" "chore: bump version"

# Branch flow: feature -> dev -> staging -> main
ExpectCheck "feature branch into staging fails" fail "feature/add-login" staging "feat: add login" "${goodCommits[@]}"
ExpectCheck "feature branch into main fails" fail "feature/add-login" main "feat: add login" "${goodCommits[@]}"
ExpectCheck "dev into staging passes" pass dev staging "chore: release to testflight" "${goodCommits[@]}"
ExpectCheck "staging into main passes" pass staging main "chore: release to app store" "${goodCommits[@]}"
ExpectCheck "dev into main fails" fail dev main "chore: release" "${goodCommits[@]}"
ExpectCheck "hotfix into main passes" pass "hotfix/patch-token-leak" main "fix: patch token leak" "fix: stop logging tokens"
ExpectCheck "main back into dev passes" pass main dev "chore: sync hotfix" "fix: stop logging tokens"

# Commit messages and PR title
ExpectCheck "merge commits are allowed" pass "feature/add-login" dev "feat: add login" "feat: add login" "Merge branch 'dev' into feature/add-login"
ExpectCheck "breaking change marker passes" pass "feature/add-login" dev "feat!: replace login" "feat(auth)!: replace token storage"
ExpectCheck "ops type passes" pass "chore/update-runner" dev "ops: update runner" "ops: update runner"
ExpectCheck "commit without type fails" fail "feature/add-login" dev "feat: add login" "add login screen"
ExpectCheck "commit with unknown type fails" fail "feature/add-login" dev "feat: add login" "feature: add login screen"
ExpectCheck "commit missing space after colon fails" fail "feature/add-login" dev "feat: add login" "feat:add login screen"
ExpectCheck "title without type fails" fail "feature/add-login" dev "Add login" "${goodCommits[@]}"

echo
echo "$passedCount passed, $failedCount failed"
[[ "$failedCount" -eq 0 ]]

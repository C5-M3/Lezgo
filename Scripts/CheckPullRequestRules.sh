#!/usr/bin/env bash
# Checks a pull request against the team rules in AGENTS.md:
# - the branch name follows Conventional Branch (<type>/<description>),
# - the branch flow is feature -> dev -> staging -> main,
# - the PR title and every commit follow Conventional Commits.
#
# Usage: git log --format=%s base..head | Scripts/CheckPullRequestRules.sh <head branch> <base branch> <PR title>

set -uo pipefail

headBranch="$1"
baseBranch="$2"
pullRequestTitle="$3"
errorCount=0

branchPattern='^(feature|feat|bugfix|fix|hotfix|release|chore)/[a-z0-9]+([.-][a-z0-9]+)*$'
commitPattern='^(feat|fix|refactor|perf|style|test|docs|build|ci|ops|chore)(\([A-Za-z0-9._/-]+\))?!?: [^ ].*$'
# Commits made by git itself (pulling dev in, reverting) keep their default message.
generatedCommitPattern='^(Merge |Revert ")'

ReportError() {
  if [[ -n "${GITHUB_ACTIONS:-}" ]]; then echo "::error::$1"; else echo "ERROR $1"; fi
  errorCount=$((errorCount + 1))
}

IsTrunkBranch() {
  [[ "$1" == "main" || "$1" == "staging" || "$1" == "dev" ]]
}

CheckBranchName() {
  IsTrunkBranch "$headBranch" && return
  if [[ ! "$headBranch" =~ $branchPattern ]]; then
    ReportError "Branch '$headBranch' must be <type>/<description>: type is feature, feat, bugfix, fix, hotfix, release or chore; description is lowercase words joined by hyphens (dots allowed for versions)."
  fi
}

CheckBranchFlow() {
  local allowedSources
  case "$baseBranch" in
    dev) allowedSources="a feature, bugfix, chore or hotfix branch, or main (to bring a hotfix back)" ;;
    staging) allowedSources="dev or a hotfix/ branch" ;;
    main) allowedSources="staging, a release/ branch or a hotfix/ branch" ;;
    *) return ;;
  esac

  local isAllowed=false
  case "$baseBranch:$headBranch" in
    dev:main) isAllowed=true ;;
    dev:staging | dev:dev) isAllowed=false ;;
    dev:*) isAllowed=true ;;
    staging:dev | staging:hotfix/*) isAllowed=true ;;
    main:staging | main:release/* | main:hotfix/*) isAllowed=true ;;
  esac

  if [[ "$isAllowed" == false ]]; then
    ReportError "'$headBranch' cannot be merged into '$baseBranch'. Only $allowedSources can target '$baseBranch'."
  fi
}

CheckTitle() {
  if [[ ! "$pullRequestTitle" =~ $commitPattern ]]; then
    ReportError "PR title '$pullRequestTitle' must follow Conventional Commits, for example 'feat(login): add email validation'."
  fi
}

CheckCommits() {
  local subject
  while IFS= read -r subject; do
    [[ -z "$subject" ]] && continue
    [[ "$subject" =~ $generatedCommitPattern ]] && continue
    if [[ ! "$subject" =~ $commitPattern ]]; then
      ReportError "Commit '$subject' must follow Conventional Commits: <type>(<optional scope>): <summary>."
    fi
  done
}

CheckBranchName
CheckBranchFlow
CheckTitle
CheckCommits

if [[ "$errorCount" -eq 0 ]]; then
  echo "Pull request rules passed."
else
  echo "Pull request rules failed with $errorCount error(s). See AGENTS.md and README.md."
fi
[[ "$errorCount" -eq 0 ]]

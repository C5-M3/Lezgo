#!/usr/bin/env bash
# Tests for ci_scripts/ci_post_clone.sh (ADR 0035).
# Each test clones a throwaway origin without its tags, as Xcode Cloud may, and runs the script in the clone.

set -uo pipefail

repoRoot="$(cd "$(dirname "$0")/../.." && pwd)"
workDirectory="$(mktemp -d)"
trap 'rm -rf "$workDirectory"' EXIT

passedCount=0
failedCount=0

# NewClone <tag on the last commit, or "none">: prints the path of a fresh clone that has no tags yet.
NewClone() {
  local tag="$1" origin clone
  origin="$(mktemp -d "$workDirectory/origin.XXXXXX")"
  clone="$(mktemp -d "$workDirectory/clone.XXXXXX")"
  (
    cd "$origin" || exit 1
    git init -q -b main
    git config user.email "tests@example.com"
    git config user.name "Tests"
    git config commit.gpgsign false
    mkdir -p ci_scripts Scripts Config
    cp "$repoRoot/ci_scripts/ci_post_clone.sh" ci_scripts/ 2>/dev/null
    cp "$repoRoot/Scripts/AppVersion.sh" Scripts/
    git add . && git commit -q -m "chore: first"
    git tag v1.0.0
    git commit -q --allow-empty -m "chore: second"
    [[ "$tag" == "none" ]] || git tag "$tag"
  ) || exit 1
  git clone -q --no-tags "$origin" "$clone"
  echo "$clone"
}

# Expect <name> <branch> <tag on the last commit, or "none"> <expected CI.xcconfig line, or "fail">
Expect() {
  local name="$1" branch="$2" tag="$3" expected="$4" clone actual
  clone="$(NewClone "$tag")"
  if CI_PRIMARY_REPOSITORY_PATH="$clone" CI_BRANCH="$branch" bash "$clone/ci_scripts/ci_post_clone.sh" > /dev/null 2>&1; then
    actual="$(grep '^MARKETING_VERSION' "$clone/Config/CI.xcconfig" 2>/dev/null || echo "no CI.xcconfig")"
  else
    actual="fail"
  fi

  if [[ "$actual" == "$expected" ]]; then
    passedCount=$((passedCount + 1))
    echo "ok   $name"
  else
    failedCount=$((failedCount + 1))
    echo "FAIL $name (expected '$expected', got '$actual')"
  fi
}

Expect "main fetches the tags and uses the release tag" main v1.1.0 "MARKETING_VERSION = 1.1.0"
Expect "staging uses the next fix after the latest release" staging v1.1.0 "MARKETING_VERSION = 1.1.1"
Expect "dev uses the next fix after the latest release" dev none "MARKETING_VERSION = 1.0.1"
Expect "main stops the build when the commit has no release tag" main none fail

echo
echo "$passedCount passed, $failedCount failed"
[[ "$failedCount" -eq 0 ]]

#!/usr/bin/env bash
# Tests for Scripts/AppVersion.sh (ADR 0035).
# Each test builds a throwaway git repository with release tags and runs the script inside it.

set -uo pipefail

repoRoot="$(cd "$(dirname "$0")/../.." && pwd)"
script="$repoRoot/Scripts/AppVersion.sh"
workDirectory="$(mktemp -d)"
trap 'rm -rf "$workDirectory"' EXIT

passedCount=0
failedCount=0

# NewRepository: an empty repository with one commit, as the current directory.
NewRepository() {
  local path
  path="$(mktemp -d "$workDirectory/repo.XXXXXX")"
  cd "$path" || exit 1
  git init -q
  git config user.email "tests@example.com"
  git config user.name "Tests"
  git config commit.gpgsign false
  git config tag.gpgsign false
  AddCommit
}

AddCommit() {
  git commit -q --allow-empty -m "chore: commit $RANDOM"
}

AddTag() {
  git tag "$1"
}

# Expect <name> <expected output, or "fail"> <arguments...>
Expect() {
  local name="$1" expected="$2" actual
  shift 2
  if actual="$("$script" "$@" 2>/dev/null)"; then
    :
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

# Latest release
NewRepository
AddTag v1.0.0
AddCommit
AddTag v1.0.1
AddCommit
AddTag v1.0.10
Expect "latest picks the highest number, not the newest name in text order" "1.0.10" latest

NewRepository
AddTag v1.2.0
AddTag v2.0.0-beta
AddTag release-3
AddTag v9
Expect "latest ignores tags that are not vX.Y.Z" "1.2.0" latest

NewRepository
Expect "latest fails without a release tag" fail latest

# Next release
NewRepository
AddTag v1.0.1
Expect "a fix raises the last number" "1.0.2" next fix
Expect "a feature raises the middle number and resets the last" "1.1.0" next feature
Expect "a big update raises the first number and resets the others" "2.0.0" next big-update
Expect "an unknown kind of release fails" fail next minor
Expect "a missing kind of release fails" fail next

NewRepository
AddTag v1.9.9
Expect "numbers grow past nine" "1.10.0" next feature

NewRepository
Expect "next fails without a release tag" fail next fix

# Version for an Xcode Cloud build
NewRepository
AddTag v1.0.0
AddCommit
AddTag v1.1.0
Expect "main uses the tag on the commit being built" "1.1.0" for-build main
Expect "staging uses the next fix after the latest release" "1.1.1" for-build staging
Expect "dev uses the next fix after the latest release" "1.1.1" for-build dev
Expect "a feature branch uses the next fix after the latest release" "1.1.1" for-build feature/issue-1-add-login

AddCommit
Expect "main fails when the commit being built has no release tag" fail for-build main

NewRepository
Expect "staging fails without any release tag" fail for-build staging

Expect "an unknown command fails" fail publish

echo
echo "$passedCount passed, $failedCount failed"
[[ "$failedCount" -eq 0 ]]

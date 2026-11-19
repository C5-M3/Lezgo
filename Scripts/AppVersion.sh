#!/usr/bin/env bash
# Works out the app version (MARKETING_VERSION) from the release tags vX.Y.Z (ADR 0035).
# Run it inside the repository, with the tags fetched.
#
#   AppVersion.sh latest              The latest release, for example 1.0.1.
#   AppVersion.sh next <kind>         The release after it. kind is fix (1.0.2), feature (1.1.0) or big-update (2.0.0).
#   AppVersion.sh for-build <branch>  The version an Xcode Cloud build of <branch> must carry:
#                                     on main, the release tag on the commit being built;
#                                     on any other branch, the next fix, so TestFlight never gets a closed version.

set -euo pipefail

Fail() {
  echo "AppVersion: $1" >&2
  exit 1
}

# Prints the release tags in the given list as plain versions, highest last.
SortReleases() {
  grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' | sed 's/^v//' | sort -t . -k 1,1n -k 2,2n -k 3,3n || true
}

Latest() {
  local version
  version="$(git tag --list 'v*' | SortReleases | tail -n 1)"
  [[ -n "$version" ]] || Fail "no release tag (vX.Y.Z) found. Fetch the tags, or tag the last App Store release."
  echo "$version"
}

Next() {
  local kind="$1" latest major minor patch
  # Assigned on its own line: a failure inside "$(...)" in a here-string would not stop the script.
  latest="$(Latest)"
  IFS=. read -r major minor patch <<< "$latest"
  case "$kind" in
    fix) echo "$major.$minor.$((patch + 1))" ;;
    feature) echo "$major.$((minor + 1)).0" ;;
    big-update) echo "$((major + 1)).0.0" ;;
    *) Fail "unknown kind of release '$kind'. Use fix, feature or big-update." ;;
  esac
}

ForBuild() {
  local branch="$1" version
  if [[ "$branch" != "main" ]]; then
    Next fix
    return
  fi

  version="$(git tag --points-at HEAD --list 'v*' | SortReleases | tail -n 1)"
  [[ -n "$version" ]] || Fail "the commit on main has no release tag. Release with the Promote workflow, which tags it."
  echo "$version"
}

command="${1:-}"
case "$command" in
  latest) Latest ;;
  next) Next "${2:-}" ;;
  for-build) ForBuild "${2:-}" ;;
  *) Fail "unknown command '$command'. Use latest, next <kind> or for-build <branch>." ;;
esac

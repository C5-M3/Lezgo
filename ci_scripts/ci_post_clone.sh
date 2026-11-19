#!/usr/bin/env bash
# Xcode Cloud runs this after it clones the repository, before every build (ADR 0035).
# It writes the app version for this build into Config/CI.xcconfig, which Config/Base.xcconfig includes last.
# It only reads git tags and writes that one git-ignored file; it downloads and installs nothing.

set -euo pipefail

repository="${CI_PRIMARY_REPOSITORY_PATH:?Xcode Cloud sets CI_PRIMARY_REPOSITORY_PATH}"
branch="${CI_BRANCH:-}"
cd "$repository"

# Xcode Cloud may clone without tags. Without them a main build stops below instead of guessing a version.
git fetch --tags --force --quiet origin || echo "warning: could not fetch the release tags"

version="$(Scripts/AppVersion.sh for-build "$branch")"
printf '// Written by ci_scripts/ci_post_clone.sh for this Xcode Cloud build. Do not commit.\nMARKETING_VERSION = %s\n' "$version" > Config/CI.xcconfig
echo "Building ${branch:-an unknown branch} as version $version"

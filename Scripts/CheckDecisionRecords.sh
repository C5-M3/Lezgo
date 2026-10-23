#!/usr/bin/env bash
# Checks the architecture decision records (ADRs) so the index and the files never drift apart:
# - file names are NNNN-PascalCaseTitle.md, numbered from 0001 with no gaps or duplicates,
# - the heading number matches the file number,
# - each record has a valid Status and Date and the four required sections,
# - "Superseded by NNNN" points to a record that exists,
# - the index (README.md) lists every record with the same status, and links to no missing file.
#
# Usage: Scripts/CheckDecisionRecords.sh [ADR folder, default docs/adr]

set -uo pipefail

adrDir="${1:-docs/adr}"
indexFile="$adrDir/README.md"
errorCount=0

fileNamePattern='^[0-9]{4}-[A-Z][A-Za-z0-9]*\.md$'
statusPattern='^(Proposed|Accepted|Deprecated|Superseded by [0-9]{4})$'
datePattern='^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
requiredSections=("## Context" "## Decision" "## Alternatives considered" "## Consequences")

ReportError() {
  local file="$1" message="$2"
  if [[ -n "${GITHUB_ACTIONS:-}" ]]; then
    echo "::error file=$file::$message"
  else
    echo "ERROR $file: $message"
  fi
  errorCount=$((errorCount + 1))
}

# Prints the value after "- <field>: " in a record, or nothing.
ReadField() {
  grep -m1 -E "^- $2: " "$1" | sed -E "s/^- $2: //"
}

CheckRecord() {
  local file="$1" fileName number status date section supersededNumber
  fileName="$(basename "$file")"
  number="${fileName%%-*}"

  if [[ ! "$fileName" =~ $fileNamePattern ]]; then
    ReportError "$file" "File name must be NNNN-PascalCaseTitle.md, for example 0003-MvvmLayerFirst.md."
  fi

  if ! head -n 1 "$file" | grep -qE "^# $number\. .+"; then
    ReportError "$file" "First line must be '# $number. <Title>'."
  fi

  status="$(ReadField "$file" Status)"
  if [[ ! "$status" =~ $statusPattern ]]; then
    ReportError "$file" "Status must be Proposed, Accepted, Deprecated or 'Superseded by NNNN' (found '$status')."
  elif [[ "$status" == Superseded* ]]; then
    supersededNumber="${status##* }"
    if ! ls "$adrDir/$supersededNumber"-*.md > /dev/null 2>&1; then
      ReportError "$file" "Status says 'Superseded by $supersededNumber', but no record $supersededNumber exists."
    fi
  fi

  date="$(ReadField "$file" Date)"
  if [[ ! "$date" =~ $datePattern ]]; then
    ReportError "$file" "Date must be YYYY-MM-DD (found '$date')."
  fi

  for section in "${requiredSections[@]}"; do
    if ! grep -qxF "$section" "$file"; then
      ReportError "$file" "Missing section '$section'."
    fi
  done

  CheckIndexEntry "$file" "$fileName" "$status"
}

CheckIndexEntry() {
  local file="$1" fileName="$2" status="$3" row
  row="$(grep -F "]($fileName)" "$indexFile")"
  if [[ -z "$row" ]]; then
    ReportError "$indexFile" "Index has no row linking to $fileName."
  elif [[ "$row" != *"| $status |"* ]]; then
    ReportError "$indexFile" "Index status for $fileName does not match the record ('$status')."
  fi
}

CheckNumbering() {
  local expected=1 number
  for number in $(ls "$adrDir" | grep -E '^[0-9]{4}-' | cut -c1-4 | sort); do
    if [[ "$((10#$number))" -ne "$expected" ]]; then
      ReportError "$adrDir" "Record numbers must run from 0001 with no gaps or duplicates (expected $(printf '%04d' "$expected"), found $number)."
      return
    fi
    expected=$((expected + 1))
  done
}

CheckIndexLinks() {
  local linkedFile
  for linkedFile in $(grep -oE '\]\([0-9]{4}-[^)]+\.md\)' "$indexFile" | sed -E 's/^\]\((.*)\)$/\1/'); do
    if [[ ! -f "$adrDir/$linkedFile" ]]; then
      ReportError "$indexFile" "Index links to $linkedFile, which does not exist."
    fi
  done
}

if [[ ! -f "$indexFile" ]]; then
  ReportError "$indexFile" "Missing index file."
  exit 1
fi

for recordFile in "$adrDir"/[0-9][0-9][0-9][0-9]-*.md; do
  [[ -e "$recordFile" ]] || continue
  CheckRecord "$recordFile"
done
CheckNumbering
CheckIndexLinks

echo "ADR check finished: $errorCount error(s)."
[[ "$errorCount" -eq 0 ]]

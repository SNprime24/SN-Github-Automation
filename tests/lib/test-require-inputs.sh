#!/usr/bin/env bash
# Checks that lib/require-inputs.sh names every empty input and passes when none is empty.
set -euo pipefail

script="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../lib/require-inputs.sh"
failures=0

check() {
  local name=$1 expected_status=$2 expected_output=$3 output status vars
  read -ra vars <<<"$4"
  shift 4
  set +e
  output=$(env "$@" bash "$script" "${vars[@]}" 2>&1)
  status=$?
  set -e
  if [[ $status == "$expected_status" && $output == "$expected_output" ]]; then
    echo "PASS  $name"
  else
    echo "FAIL  $name: exit $status, output:"
    echo "$output"
    failures=$((failures + 1))
  fi
}

check "all inputs set" 0 "" \
  "OWNER PROJECT_NUMBER" OWNER=someone PROJECT_NUMBER=1
check "each empty input is named" 1 "::error::The project-number input is required
::error::The sprint-fill-days input is required" \
  "OWNER PROJECT_NUMBER SPRINT_FILL_DAYS" OWNER=someone PROJECT_NUMBER=

if ((failures)); then
  echo "$failures case(s) failed"
  exit 1
fi
echo "All cases passed"

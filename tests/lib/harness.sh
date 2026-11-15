#!/usr/bin/env bash
# Test setup shared by the script tests: puts fake-gh.sh on PATH and defines reset_data, run_case and finish.

harness_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
mkdir "$work/bin"
cp "$harness_dir/fake-gh.sh" "$work/bin/gh"
chmod +x "$work/bin/gh"
data="$work/data"
failures=0

reset_data() {
  rm -rf "$data"
  mkdir -p "$data/issues" "$data/timeline"
}

# NAME SCRIPT EXPECTED_STATUS EXPECTED_CALLS EXPECTED_OUTPUT_LINES [VAR=value...]
run_case() {
  local name=$1 script=$2 expected_status=$3 expected_calls=$4 expected_output=$5
  shift 5
  local output status line ok=1

  : >"$data/calls.log"
  set +e
  output=$(env PATH="$work/bin:$PATH" FAKE_GH_DIR="$data" GH_TOKEN=fake OWNER=someone PROJECT_NUMBER=1 \
    "$@" bash "$script" 2>&1)
  status=$?
  set -e

  if [[ $status -ne $expected_status ]]; then
    echo "  exit status $status, expected $expected_status"
    ok=0
  fi
  if [[ "$(cat "$data/calls.log")" != "$expected_calls" ]]; then
    echo "  calls were:"
    while IFS= read -r line; do echo "    $line"; done <"$data/calls.log"
    echo "  expected:"
    while IFS= read -r line; do echo "    $line"; done <<<"$expected_calls"
    ok=0
  fi
  while IFS= read -r line; do
    if [[ -n $line ]] && ! grep -qF -- "$line" <<<"$output"; then
      echo "  output doesn't contain: $line"
      ok=0
    fi
  done <<<"$expected_output"

  if ((ok)); then
    echo "PASS  $name"
  else
    echo "FAIL  $name"
    echo "  output:"
    while IFS= read -r line; do echo "    $line"; done <<<"$output"
    failures=$((failures + 1))
  fi
}

finish() {
  if ((failures)); then
    echo "$failures case(s) failed"
    exit 1
  fi
  echo "All cases passed"
}

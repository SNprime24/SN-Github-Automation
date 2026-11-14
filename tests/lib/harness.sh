#!/usr/bin/env bash
# Shared test setup for scripts that call gh. Source it from a test file.
# It puts fake-gh.sh on PATH as `gh` and defines:
#   $data         directory the fake gh reads its responses from
#   reset_data    empties $data
#   run_case      runs a script and checks its exit status, calls and output
#   finish        prints the result and exits 1 if any case failed

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

# run_case NAME SCRIPT EXPECTED_STATUS EXPECTED_CALLS EXPECTED_OUTPUT [VAR=value...]
#   EXPECTED_CALLS   the exact calls.log the fake gh should end up with, one call per line
#   EXPECTED_OUTPUT  lines that must each appear somewhere in the output (empty for none)
#   VAR=value        extra environment for the script. OWNER is "someone", PROJECT_NUMBER 1.
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
    [[ -z $line ]] && continue
    if ! grep -qF -- "$line" <<<"$output"; then
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

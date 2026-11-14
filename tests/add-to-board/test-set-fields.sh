#!/usr/bin/env bash
# Runs actions/add-to-board/set-fields.sh against a fake `gh` and checks which
# field updates it makes. Needs bash and jq.
#
#   bash tests/add-to-board/test-set-fields.sh
set -euo pipefail

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
script="$here/../../actions/add-to-board/set-fields.sh"

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
mkdir "$work/bin"
cp "$here/fake-gh.sh" "$work/bin/gh"
chmod +x "$work/bin/gh"

failures=0

# Board with Priority, Size and Status single-select fields, a Sprint iteration
# field (iterations deliberately out of order), and a text field, which the
# real API returns as {} because the query has no fragment for it.
board() {
  local iterations=$1
  cat <<EOF
{ "data": { "user": { "projectV2": {
  "id": "PROJ",
  "fields": { "nodes": [
    {},
    { "id": "F_PRIO", "name": "Priority", "options": [
      { "id": "O_HIGH", "name": "High" }, { "id": "O_NORMAL", "name": "Normal" } ] },
    { "id": "F_SIZE", "name": "Size", "options": [
      { "id": "O_S", "name": "S" }, { "id": "O_M", "name": "M" } ] },
    { "id": "F_STATUS", "name": "Status", "options": [
      { "id": "O_BACKLOG", "name": "Backlog" }, { "id": "O_DONE", "name": "Done" } ] },
    { "id": "F_SPRINT", "name": "Sprint", "configuration": { "iterations": $iterations } }
  ] }
} } } }
EOF
}

past_and_future='[
  { "id": "I_LATER", "title": "Sprint 3", "startDate": "2999-01-15" },
  { "id": "I_PAST",  "title": "Sprint 1", "startDate": "2000-01-01" },
  { "id": "I_NEXT",  "title": "Sprint 2", "startDate": "2999-01-01" }
]'
past_only='[ { "id": "I_PAST", "title": "Sprint 1", "startDate": "2000-01-01" } ]'

# Item whose set fields are the given names (single-select or iteration).
item() {
  local nodes='{}' name
  for name in "$@"; do
    nodes+=", { \"field\": { \"name\": \"$name\" } }"
  done
  echo "{ \"data\": { \"node\": { \"fieldValues\": { \"nodes\": [ $nodes ] } } } }"
}

# run_case NAME DEFAULTS EXPECTED_MUTATIONS EXPECTED_OUTPUT_GREP
run_case() {
  local name=$1 defaults=$2 expected=$3 expect_output=$4 output status
  : >"$work/mutations.log"
  set +e
  output=$(PATH="$work/bin:$PATH" FAKE_GH_DIR="$work" GH_TOKEN=fake ITEM_ID=ITEM \
    OWNER=someone PROJECT_NUMBER=1 DEFAULTS="$defaults" SPRINT_TZ=UTC \
    bash "$script" 2>&1)
  status=$?
  set -e

  local ok=1
  if [[ $status -ne 0 ]]; then
    echo "  exit status $status, expected 0"
    ok=0
  fi
  if [[ "$(cat "$work/mutations.log")" != "$expected" ]]; then
    echo "  field updates were:"
    sed 's/^/    /' "$work/mutations.log"
    echo "  expected:"
    printf '%s\n' "$expected" | sed 's/^/    /'
    ok=0
  fi
  if [[ -n $expect_output ]] && ! grep -qF -- "$expect_output" <<<"$output"; then
    echo "  output doesn't contain: $expect_output"
    ok=0
  fi

  if ((ok)); then
    echo "PASS  $name"
  else
    echo "FAIL  $name"
    echo "  output:"
    sed 's/^/    /' <<<"$output"
    failures=$((failures + 1))
  fi
}

defaults="Priority=Normal Size=M Status=Backlog"

board "$past_and_future" >"$work/project.json"
item >"$work/item.json"
run_case "empty card gets every default and the next sprint" "$defaults" \
  "project=PROJ item=ITEM field=F_PRIO option=O_NORMAL
project=PROJ item=ITEM field=F_SIZE option=O_M
project=PROJ item=ITEM field=F_STATUS option=O_BACKLOG
project=PROJ item=ITEM field=F_SPRINT iteration=I_NEXT" \
  "Set Sprint = Sprint 2"

item Priority Sprint >"$work/item.json"
run_case "fields already set are left alone" "$defaults" \
  "project=PROJ item=ITEM field=F_SIZE option=O_M
project=PROJ item=ITEM field=F_STATUS option=O_BACKLOG" \
  "Sprint already set"

item >"$work/item.json"
run_case "unknown field or option warns and carries on" "Priority=Urgent Effort=High Status=Backlog" \
  "project=PROJ item=ITEM field=F_STATUS option=O_BACKLOG
project=PROJ item=ITEM field=F_SPRINT iteration=I_NEXT" \
  "::warning::Field 'Priority' or option 'Urgent' not found on the board"

board "$past_only" >"$work/project.json"
item Priority Size Status >"$work/item.json"
run_case "no future sprint warns and leaves Sprint empty" "$defaults" \
  "" \
  "::warning::No sprint starts after"

if ((failures)); then
  echo "$failures case(s) failed"
  exit 1
fi
echo "All cases passed"

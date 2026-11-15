#!/usr/bin/env bash
# Runs actions/add-to-board/set-fields.sh against the fake gh.
set -euo pipefail

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
script="$here/../../actions/add-to-board/set-fields.sh"
# shellcheck source=tests/lib/harness.sh
source "$here/../lib/harness.sh"

board() {
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
    { "id": "F_SPRINT", "name": "Sprint", "configuration": { "iterations": $1 } }
  ] }
} } } }
EOF
}

# The card with the given fields set
card() {
  local nodes='{}' name
  for name in "$@"; do
    nodes+=", { \"field\": { \"name\": \"$name\" } }"
  done
  echo "{ \"data\": { \"node\": { \"fieldValues\": { \"nodes\": [ $nodes ] } } } }"
}

past_and_future='[
  { "id": "I_LATER", "title": "Sprint 3", "startDate": "2999-01-15", "duration": 14 },
  { "id": "I_PAST",  "title": "Sprint 1", "startDate": "2000-01-01", "duration": 14 },
  { "id": "I_NEXT",  "title": "Sprint 2", "startDate": "2999-01-01", "duration": 14 }
]'
past_only='[ { "id": "I_PAST", "title": "Sprint 1", "startDate": "2000-01-01", "duration": 14 } ]'
env=(ITEM_ID=ITEM DEFAULTS="Priority=Normal Size=M Status=Backlog" SPRINT_TZ=UTC)

reset_data
board "$past_and_future" >"$data/project.json"
card >"$data/item.json"
run_case "empty card gets every default and the next sprint" "$script" 0 \
  "set project=PROJ item=ITEM field=F_PRIO option=O_NORMAL
set project=PROJ item=ITEM field=F_SIZE option=O_M
set project=PROJ item=ITEM field=F_STATUS option=O_BACKLOG
set project=PROJ item=ITEM field=F_SPRINT iteration=I_NEXT" \
  "Filled 3 empty fields
Set Sprint = Sprint 2" \
  "${env[@]}"

card Priority Sprint >"$data/item.json"
run_case "fields already set are left alone" "$script" 0 \
  "set project=PROJ item=ITEM field=F_SIZE option=O_M
set project=PROJ item=ITEM field=F_STATUS option=O_BACKLOG" \
  "Filled 2 empty fields
Sprint already set" \
  "${env[@]}"

card >"$data/item.json"
run_case "unknown field or option warns and carries on" "$script" 0 \
  "set project=PROJ item=ITEM field=F_STATUS option=O_BACKLOG
set project=PROJ item=ITEM field=F_SPRINT iteration=I_NEXT" \
  "::warning::Field 'Priority' or option 'Urgent' not found on the board
::warning::Field 'Effort' or option 'High' not found on the board" \
  "${env[@]}" DEFAULTS="Priority=Urgent Effort=High Status=Backlog"

board "$past_only" >"$data/project.json"
card Priority Size Status >"$data/item.json"
run_case "no future sprint warns and leaves Sprint empty" "$script" 0 \
  "" \
  "::warning::No sprint starts after" \
  "${env[@]}"

finish

#!/usr/bin/env bash
# Runs the board-sweep scripts against a fake `gh` and checks which changes they
# make. Needs bash and jq.
#
#   bash tests/board-sweep/test-board-sweep.sh
set -euo pipefail

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
action="$here/../../actions/board-sweep"
# shellcheck source=tests/lib/harness.sh
source "$here/../lib/harness.sh"

# Board with Priority, Size and Status single-select fields, a Sprint iteration
# field with the given iterations, and a text field, which the real API returns
# as {} because the query has no fragment for it.
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
      { "id": "O_BACKLOG", "name": "Backlog" }, { "id": "O_TODO", "name": "Todo" },
      { "id": "O_PROG", "name": "In progress" }, { "id": "O_DONE", "name": "Done" } ] },
    { "id": "F_SPRINT", "name": "Sprint", "configuration": { "iterations": $1 } }
  ] }
} } } }
EOF
}

# One page of board items with the given nodes.
items_page() {
  echo "{ \"data\": { \"user\": { \"projectV2\": { \"items\": {
    \"pageInfo\": { \"hasNextPage\": false, \"endCursor\": null }, \"nodes\": [ $1 ] } } } } }"
}

# Iterations deliberately out of order. 2999 is always in the future and 2000 in the past.
two_upcoming='[
  { "id": "I_LATER", "title": "Sprint 3", "startDate": "2999-01-15", "duration": 14 },
  { "id": "I_PAST",  "title": "Sprint 1", "startDate": "2000-01-01", "duration": 14 },
  { "id": "I_NEXT",  "title": "Sprint 2", "startDate": "2999-01-01", "duration": 14 }
]'
one_short_upcoming='[
  { "id": "I_PAST", "title": "Sprint 1", "startDate": "2000-01-01", "duration": 14 },
  { "id": "I_NEXT", "title": "Sprint 2", "startDate": "2999-01-01", "duration": 7 }
]'
none_upcoming='[ { "id": "I_PAST", "title": "Sprint 1", "startDate": "2000-01-01", "duration": 14 } ]'

fill_env=(DEFAULTS="Priority=Normal Size=M Status=Backlog" SPRINT_TZ=UTC SPRINT_FILL_DAYS=3 SPRINT_LENGTH_DAYS=14)

# Cards for the fill step. A card added in 2999 counts as recent, one added in 2000 doesn't.
empty_recent='{ "id": "A", "isArchived": false, "createdAt": "2999-01-01T00:00:00Z", "fieldValues": { "nodes": [ {} ] } }'
empty_old='{ "id": "B", "isArchived": false, "createdAt": "2000-01-01T00:00:00Z", "fieldValues": { "nodes": [] } }'
done_recent='{ "id": "C", "isArchived": false, "createdAt": "2999-01-01T00:00:00Z", "fieldValues": { "nodes": [
  { "name": "Done", "field": { "name": "Status" } } ] } }'
archived='{ "id": "D", "isArchived": true, "createdAt": "2999-01-01T00:00:00Z", "fieldValues": { "nodes": [] } }'
all_set='{ "id": "E", "isArchived": false, "createdAt": "2999-01-01T00:00:00Z", "fieldValues": { "nodes": [
  { "name": "High", "field": { "name": "Priority" } }, { "name": "S", "field": { "name": "Size" } },
  { "name": "Todo", "field": { "name": "Status" } }, { "field": { "name": "Sprint" } } ] } }'

### add-missing.sh

reset_data
board "$two_upcoming" >"$data/project.json"
cat >"$data/repos.json" <<'EOF'
[ { "name": "app", "hasIssuesEnabled": true },
  { "name": "private-notes", "hasIssuesEnabled": true } ]
EOF
echo '[ { "id": "ISSUE_1" }, { "id": "ISSUE_2" } ]' >"$data/issues/app.json"
echo '[ { "id": "ISSUE_SKIPPED" } ]' >"$data/issues/private-notes.json"
cat >"$data/search.json" <<'EOF'
[ { "id": "ISSUE_3", "repository": { "nameWithOwner": "friend/their-repo" } },
  { "id": "ISSUE_1", "repository": { "nameWithOwner": "someone/app" } } ]
EOF
run_case "adds open issues from own repos, except skipped ones, and assigned issues elsewhere" \
  "$action/add-missing.sh" 0 \
  "add project=PROJ content=ISSUE_1
add project=PROJ content=ISSUE_2
add project=PROJ content=ISSUE_3" \
  "Skipping private-notes
Checked 2 open issues across 2 repos
Checked 1 open issues assigned to someone in repos owned by others" \
  SKIP_REPOS="other private-notes"

### fill-defaults.sh

reset_data
board "$two_upcoming" >"$data/project.json"
items_page "$empty_recent, $empty_old, $done_recent, $archived, $all_set" >"$data/items.json"
run_case "fills empty fields everywhere and Sprint only on recent cards that aren't Done" \
  "$action/fill-defaults.sh" 0 \
  "set project=PROJ item=A field=F_PRIO option=O_NORMAL
set project=PROJ item=A field=F_SIZE option=O_M
set project=PROJ item=A field=F_STATUS option=O_BACKLOG
set project=PROJ item=A field=F_SPRINT iteration=I_NEXT
set project=PROJ item=B field=F_PRIO option=O_NORMAL
set project=PROJ item=B field=F_SIZE option=O_M
set project=PROJ item=B field=F_STATUS option=O_BACKLOG
set project=PROJ item=C field=F_PRIO option=O_NORMAL
set project=PROJ item=C field=F_SIZE option=O_M" \
  "Filled 8 empty Priority/Size/Status values and 1 empty Sprints" \
  "${fill_env[@]}"

items_page "$empty_recent" >"$data/items.json"
run_case "unknown field or option warns and carries on" \
  "$action/fill-defaults.sh" 0 \
  "set project=PROJ item=A field=F_STATUS option=O_BACKLOG
set project=PROJ item=A field=F_SPRINT iteration=I_NEXT" \
  "::warning::Field 'Priority' or option 'Urgent' not found on the board
::warning::Field 'Effort' or option 'High' not found on the board" \
  "${fill_env[@]}" DEFAULTS="Priority=Urgent Effort=High Status=Backlog"

board "$one_short_upcoming" >"$data/project.json"
items_page "$all_set" >"$data/items.json"
run_case "warns about a sprint of the wrong length and when only one is left" \
  "$action/fill-defaults.sh" 0 \
  "" \
  "Filled 0 empty Priority/Size/Status values and 0 empty Sprints
::warning::Sprint 2 is 7 days long, not 14
::warning::Only one upcoming sprint is left" \
  "${fill_env[@]}"

board "$none_upcoming" >"$data/project.json"
items_page "$empty_recent" >"$data/items.json"
run_case "fills the defaults, then fails when no sprint is left" \
  "$action/fill-defaults.sh" 1 \
  "set project=PROJ item=A field=F_PRIO option=O_NORMAL
set project=PROJ item=A field=F_SIZE option=O_M
set project=PROJ item=A field=F_STATUS option=O_BACKLOG" \
  "::error::No sprint starts after" \
  "${fill_env[@]}"

### reopen-moved.sh

# closed_card ITEM ISSUE STATE CAN_REOPEN STATUS OPTION [ARCHIVED]
# The issue closed on 2026-01-01.
closed_card() {
  echo "{ \"id\": \"$1\", \"isArchived\": ${7:-false},
    \"content\": { \"id\": \"$2\", \"url\": \"https://github.com/someone/app/issues/${2#ISSUE_}\",
      \"state\": \"$3\", \"closedAt\": \"2026-01-01T00:00:00Z\", \"viewerCanReopen\": $4 },
    \"fieldValueByName\": { \"name\": \"$5\", \"optionId\": \"$6\", \"field\": { \"id\": \"F_STATUS\" } } }"
}

# status_changes PROJECT DATE: the card was moved out of Done on that board on DATE.
status_changes() {
  echo "{ \"data\": { \"node\": { \"timelineItems\": { \"nodes\": [
    { \"createdAt\": \"2025-12-30T00:00:00Z\", \"previousStatus\": \"Todo\", \"project\": { \"id\": \"PROJ\" } },
    { \"createdAt\": \"$2\", \"previousStatus\": \"Done\", \"project\": { \"id\": \"$1\" } } ] } } } }"
}

reset_data
board "$two_upcoming" >"$data/project.json"
items_page "$(closed_card ITEM_1 ISSUE_1 CLOSED true 'In progress' O_PROG),
  $(closed_card ITEM_2 ISSUE_2 CLOSED true Todo O_TODO),
  $(closed_card ITEM_3 ISSUE_3 CLOSED false Todo O_TODO),
  $(closed_card ITEM_4 ISSUE_4 CLOSED true Done O_DONE),
  $(closed_card ITEM_5 ISSUE_5 OPEN true Todo O_TODO),
  $(closed_card ITEM_6 ISSUE_6 CLOSED true Todo O_TODO),
  $(closed_card ITEM_7 ISSUE_7 CLOSED true Todo O_TODO true)" >"$data/closed.json"
status_changes PROJ 2026-01-02T00:00:00Z >"$data/timeline/ISSUE_1.json"
status_changes PROJ 2025-12-31T00:00:00Z >"$data/timeline/ISSUE_2.json"
status_changes PROJ 2026-01-02T00:00:00Z >"$data/timeline/ISSUE_3.json"
status_changes OTHER 2026-01-02T00:00:00Z >"$data/timeline/ISSUE_6.json"
status_changes PROJ 2026-01-02T00:00:00Z >"$data/timeline/ISSUE_7.json"
run_case "reopens only issues moved out of Done after closing, and restores their column" \
  "$action/reopen-moved.sh" 0 \
  "reopen issue=ISSUE_1
set project=PROJ item=ITEM_1 field=F_STATUS option=O_PROG" \
  "Reopened https://github.com/someone/app/issues/1 (card is in 'In progress')
Left closed: https://github.com/someone/app/issues/2 is in 'Todo'
::warning::Can't reopen https://github.com/someone/app/issues/3
Left closed: https://github.com/someone/app/issues/6 is in 'Todo'
Reopened 1 issues" \
  REOPEN_SETTLE_SECONDS=0

finish

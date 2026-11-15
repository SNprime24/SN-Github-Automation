#!/usr/bin/env bash
# Runs actions/sprint-rollover/rollover.sh against a fake `gh` and checks which
# cards it moves. Needs bash and jq.
#
#   bash tests/sprint-rollover/test-sprint-rollover.sh
set -euo pipefail

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
script="$here/../../actions/sprint-rollover/rollover.sh"
# shellcheck source=tests/lib/harness.sh
source "$here/../lib/harness.sh"

# Three 14-day sprints: Sprint 1 from 2026-01-01, Sprint 2 from 2026-01-15 and
# Sprint 3 from 2026-01-29 to 2026-02-11.
reset_data
cat >"$data/project.json" <<'EOF'
{ "data": { "user": { "projectV2": {
  "id": "PROJ",
  "fields": { "nodes": [
    {},
    { "id": "F_STATUS", "name": "Status", "options": [
      { "id": "O_BACKLOG", "name": "Backlog" }, { "id": "O_TODO", "name": "Todo" },
      { "id": "O_PROG", "name": "In progress" }, { "id": "O_DONE", "name": "Done" } ] },
    { "id": "F_SPRINT", "name": "Sprint", "configuration": { "iterations": [
      { "id": "S3", "title": "Sprint 3", "startDate": "2026-01-29", "duration": 14 },
      { "id": "S1", "title": "Sprint 1", "startDate": "2026-01-01", "duration": 14 },
      { "id": "S2", "title": "Sprint 2", "startDate": "2026-01-15", "duration": 14 } ] } }
  ] }
} } } }
EOF

# card ID CONTENT STATUS SPRINT_TITLE SPRINT_START [ARCHIVED]
card() {
  local sprint=null
  [[ -n $4 ]] && sprint="{ \"title\": \"$4\", \"startDate\": \"$5\" }"
  echo "{ \"id\": \"$1\", \"isArchived\": ${6:-false}, \"content\": $2,
    \"status\": { \"name\": \"$3\" }, \"sprint\": $sprint }"
}
own_issue='{ "id": "ISSUE_1", "url": "https://github.com/someone/app/issues/1" }'
others_issue='{ "id": "ISSUE_2", "url": "https://github.com/friend/their-repo/issues/2" }'
draft='{ "title": "Draft idea" }'
pull='{ "url": "https://github.com/someone/app/pull/3" }'
other_issue() { echo "{ \"id\": \"ISSUE_$1\", \"url\": \"https://github.com/someone/app/issues/$1\" }"; }

cat >"$data/cards.json" <<EOF
{ "data": { "user": { "projectV2": { "items": {
  "pageInfo": { "hasNextPage": false, "endCursor": null }, "nodes": [
  $(card C1 "$own_issue" Todo "Sprint 2" 2026-01-15),
  $(card C2 "$others_issue" Todo "Sprint 1" 2026-01-01),
  $(card C3 "$draft" Backlog "Sprint 2" 2026-01-15),
  $(card C4 "$(other_issue 4)" Backlog "Sprint 1" 2026-01-01),
  $(card C5 "$(other_issue 5)" Todo "Sprint 3" 2026-01-29),
  $(card C6 "$(other_issue 6)" "In progress" "Sprint 2" 2026-01-15),
  $(card C7 "$(other_issue 7)" Todo "" ""),
  $(card C8 "$(other_issue 8)" Todo "Sprint 2" 2026-01-15 true),
  $(card C9 "$pull" Todo "Sprint 2" 2026-01-15)
] } } } } }
EOF

# C1, C2, C3 and C9 move. C4 (Backlog, earlier sprint), C5 (future sprint),
# C6 (In progress), C7 (no Sprint) and C8 (archived) stay.
moves="set project=PROJ item=C1 field=F_STATUS option=O_BACKLOG
set project=PROJ item=C1 field=F_SPRINT iteration=S3
comment issue=ISSUE_1 body=Rolled over from Sprint 2
set project=PROJ item=C2 field=F_STATUS option=O_BACKLOG
set project=PROJ item=C2 field=F_SPRINT iteration=S3
set project=PROJ item=C3 field=F_STATUS option=O_BACKLOG
set project=PROJ item=C3 field=F_SPRINT iteration=S3
set project=PROJ item=C9 field=F_STATUS option=O_BACKLOG
set project=PROJ item=C9 field=F_SPRINT iteration=S3"

base_env=(SPRINT_TZ=UTC DRY_RUN=false ONLY_ON_SPRINT_START=false)

run_case "dry run lists the cards and changes nothing" "$script" 0 \
  "" \
  "Would move https://github.com/someone/app/issues/1 (Todo, Sprint 2) to Backlog in Sprint 3
Would move https://github.com/friend/their-repo/issues/2 (Todo, Sprint 1) to Backlog in Sprint 3
Would move Draft idea (Backlog, Sprint 2) to Backlog in Sprint 3
Would move https://github.com/someone/app/pull/3 (Todo, Sprint 2) to Backlog in Sprint 3
Dry run: would move 4 cards to Backlog in Sprint 3" \
  "${base_env[@]}" AS_OF=2026-01-15 DRY_RUN=true

run_case "scheduled run on the day a sprint starts moves the cards, commenting only on own issues" "$script" 0 \
  "$moves" \
  "Moved https://github.com/someone/app/issues/1 (Todo, Sprint 2) to Backlog in Sprint 3
Moved 4 cards to Backlog in Sprint 3" \
  "${base_env[@]}" AS_OF=2026-01-15 ONLY_ON_SPRINT_START=true

run_case "scheduled run on another day does nothing" "$script" 0 \
  "" \
  "Sprint 2 started on 2026-01-15, not today (2026-01-20), so there is nothing to roll over" \
  "${base_env[@]}" AS_OF=2026-01-20 ONLY_ON_SPRINT_START=true

run_case "manual run on another day catches up" "$script" 0 \
  "$moves" \
  "Moved 4 cards to Backlog in Sprint 3" \
  "${base_env[@]}" AS_OF=2026-01-20

touch "$data/fail-comment"
run_case "a failed comment warns and carries on" "$script" 0 \
  "$moves" \
  "::warning::Couldn't comment on https://github.com/someone/app/issues/1
Moved 4 cards to Backlog in Sprint 3" \
  "${base_env[@]}" AS_OF=2026-01-15
rm "$data/fail-comment"

run_case "fails when no sprint is running" "$script" 1 \
  "" \
  "::error::No sprint is running on 2025-06-01" \
  "${base_env[@]}" AS_OF=2025-06-01

run_case "fails when no sprint starts after today" "$script" 1 \
  "" \
  "::error::No sprint starts after 2026-02-05" \
  "${base_env[@]}" AS_OF=2026-02-05

finish

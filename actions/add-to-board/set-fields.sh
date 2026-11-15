#!/usr/bin/env bash
# Fills the new card's empty default fields, then an empty Sprint with the next sprint.
set -euo pipefail
# shellcheck source=lib/board.sh
source "$(dirname "${BASH_SOURCE[0]}")/../../lib/board.sh"

project=$(board_project "$OWNER" "$PROJECT_NUMBER")
project_id=$(jq -r .id <<<"$project")
filled_fields=$(board_filled_fields "$ITEM_ID")

board_resolve_defaults "$project" "$DEFAULTS"
filled=$(board_fill_defaults "$project_id" "$ITEM_ID" "$filled_fields")
echo "Filled $filled empty fields"

if has_field "$filled_fields" Sprint; then
  echo "Sprint already set"
  exit 0
fi

today=$(TZ="$SPRINT_TZ" date +%F)
next_sprint=$(board_upcoming_sprints "$project" "$today" | jq -c '.[0] // empty')
if [[ -z $next_sprint ]]; then
  echo "::warning::No sprint starts after $today, so Sprint was left empty. Add one in the project's Sprint settings; the daily sweep then fills recent cards."
  exit 0
fi

board_set_iteration "$project_id" "$ITEM_ID" "$(board_field_id "$project" Sprint)" "$(jq -r .id <<<"$next_sprint")"
echo "Set Sprint = $(jq -r .title <<<"$next_sprint")"

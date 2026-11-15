#!/usr/bin/env bash
# Fills an empty Priority / Size / Status on every card with the board defaults,
# and an empty Sprint on recently added cards that aren't Done with the next
# sprint. Then checks the upcoming sprints: it warns about sprints of the wrong
# length or when only one is left, and fails when none is left.
# Called by action.yml.
#
# Environment (set by action.yml):
#   GH_TOKEN            classic token with the repo and project scopes
#   OWNER               login of the user that owns the project
#   PROJECT_NUMBER      project number, from its URL
#   DEFAULTS            space-separated Field=Option pairs; only empty fields are filled
#   SPRINT_TZ           timezone for "today" when picking the next sprint
#   SPRINT_FILL_DAYS    only cards added in the last N days get a Sprint
#   SPRINT_LENGTH_DAYS  expected sprint length; upcoming sprints of another length get a warning

# The $names inside the single-quoted queries are GraphQL or jq variables, not shell ones.
# shellcheck disable=SC2016

set -euo pipefail
# shellcheck source=lib/board.sh
source "$(dirname "${BASH_SOURCE[0]}")/../../lib/board.sh"

project=$(board_project "$OWNER" "$PROJECT_NUMBER")
project_id=$(jq -r .id <<<"$project")

today=$(TZ="$SPRINT_TZ" date +%F)
since=$(date -u -d "$SPRINT_FILL_DAYS days ago" +%FT%TZ)
sprint_field=$(board_field_id "$project" Sprint)
upcoming=$(board_upcoming_sprints "$project" "$today")
next_sprint=$(jq -r '.[0].id // empty' <<<"$upcoming")

# Every card on the board, with the single-select and iteration fields it has set.
items_query='
  query($login: String!, $number: Int!, $endCursor: String) {
    user(login: $login) { projectV2(number: $number) {
      items(first: 100, after: $endCursor) {
        pageInfo { hasNextPage endCursor }
        nodes { id isArchived createdAt fieldValues(first: 30) { nodes {
          ... on ProjectV2ItemFieldSingleSelectValue { name field { ... on ProjectV2SingleSelectField { name } } }
          ... on ProjectV2ItemFieldIterationValue { field { ... on ProjectV2IterationField { name } } }
        } } }
      }
    } }
  }'

# One line per card that isn't archived:
#   item ID <tab> "yes" if it needs a Sprint, else "no" <tab> comma-separated names of the fields it has set
cards_filter='
  .data.user.projectV2.items.nodes[]
  | select(.isArchived | not)
  # The values that are set. Values of other field types come back as {}, with no field name.
  | [.fieldValues.nodes[] | select(.field.name)] as $values
  | ($values | map(.field.name)) as $filled
  | ($values | any(.field.name == "Status" and .name == "Done")) as $done
  # Only recent cards get a Sprint, so older cards without one stay that way.
  | (.createdAt >= $since and ($done | not) and ($filled | index("Sprint") | not)) as $needs_sprint
  | [.id, (if $needs_sprint then "yes" else "no" end), ($filled | join(","))]
  | @tsv'

items=$(gh api graphql --paginate -f query="$items_query" -f login="$OWNER" -F number="$PROJECT_NUMBER" \
  | jq -r --arg since "$since" "$cards_filter")

updated=0
sprints=0
while IFS=$'\t' read -r item needs_sprint filled; do
  [[ -z "$item" ]] && continue
  for pair in $DEFAULTS; do
    name=${pair%%=*}
    option=${pair#*=}
    [[ ",$filled," == *",$name,"* ]] && continue
    field_id=$(board_field_id "$project" "$name")
    option_id=$(board_option_id "$project" "$name" "$option")
    if [[ -z "$field_id" || -z "$option_id" ]]; then
      echo "::warning::Field '$name' or option '$option' not found on the board"
      continue
    fi
    board_set_option "$project_id" "$item" "$field_id" "$option_id"
    updated=$((updated + 1))
  done
  if [[ "$needs_sprint" == "yes" && -n "$next_sprint" ]]; then
    board_set_iteration "$project_id" "$item" "$sprint_field" "$next_sprint"
    sprints=$((sprints + 1))
  fi
done <<<"$items"

echo "Filled $updated empty Priority/Size/Status values and $sprints empty Sprints"

# Sprints have to be added by hand, and nothing else notices when they run out.
jq -r --argjson days "$SPRINT_LENGTH_DAYS" \
  '.[] | select(.duration != $days) | "::warning::\(.title) is \(.duration) days long, not \($days)"' <<<"$upcoming"
remaining=$(jq 'length' <<<"$upcoming")
if [[ "$remaining" -eq 0 ]]; then
  echo "::error::No sprint starts after $today, so new cards can't get a Sprint. Add a $SPRINT_LENGTH_DAYS-day sprint in the project's Sprint settings."
  exit 1
fi
if [[ "$remaining" -eq 1 ]]; then
  echo "::warning::Only one upcoming sprint is left. Add the next $SPRINT_LENGTH_DAYS-day sprint in the project's Sprint settings soon."
fi

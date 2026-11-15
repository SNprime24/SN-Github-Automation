#!/usr/bin/env bash
# Fills empty default fields on every card and the next sprint on recent unfinished cards, then checks sprints are left.
# shellcheck disable=SC2016 # the $names inside the query and filter are GraphQL and jq variables

set -euo pipefail
# shellcheck source=lib/board.sh
source "$(dirname "${BASH_SOURCE[0]}")/../../lib/board.sh"

project=$(board_project "$OWNER" "$PROJECT_NUMBER")
project_id=$(jq -r .id <<<"$project")
sprint_field=$(board_field_id "$project" Sprint)
today=$(TZ="$SPRINT_TZ" date +%F)
recent_since=$(date -u -d "$SPRINT_FILL_DAYS days ago" +%FT%TZ)
upcoming=$(board_upcoming_sprints "$project" "$today")
next_sprint=$(jq -r '.[0].id // empty' <<<"$upcoming")

cards_query='
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

# One line per card: item ID, whether it needs the next sprint, the names of its set fields
cards_filter='
  .data.user.projectV2.items.nodes[]
  | select(.isArchived | not)
  | [.fieldValues.nodes[] | select(.field.name)] as $values
  | ($values | map(.field.name)) as $filled
  | ($values | any(.field.name == "Status" and .name == "Done")) as $done
  | (.createdAt >= $since and ($done | not) and ($filled | index("Sprint") | not)) as $needs_sprint
  | [.id, $needs_sprint, ($filled | join(","))]
  | @tsv'

cards=$(gh api graphql --paginate -f query="$cards_query" -f login="$OWNER" -F number="$PROJECT_NUMBER" \
  | jq -r --arg since "$recent_since" "$cards_filter")

board_resolve_defaults "$project" "$DEFAULTS"
values=0
sprints=0
while IFS=$'\t' read -r item needs_sprint filled_fields; do
  [[ -z $item ]] && continue
  filled=$(board_fill_defaults "$project_id" "$item" "$filled_fields")
  values=$((values + filled))
  if [[ $needs_sprint == true && -n $next_sprint ]]; then
    board_set_iteration "$project_id" "$item" "$sprint_field" "$next_sprint"
    sprints=$((sprints + 1))
  fi
done <<<"$cards"
echo "Filled $values empty Priority/Size/Status values and $sprints empty Sprints"

jq -r --argjson days "$SPRINT_LENGTH_DAYS" \
  '.[] | select(.duration != $days) | "::warning::\(.title) is \(.duration) days long, not \($days)"' <<<"$upcoming"
case $(jq length <<<"$upcoming") in
  0)
    echo "::error::No sprint starts after $today, so new cards can't get a Sprint. Add a $SPRINT_LENGTH_DAYS-day sprint in the project's Sprint settings."
    exit 1
    ;;
  1) echo "::warning::Only one upcoming sprint is left. Add the next $SPRINT_LENGTH_DAYS-day sprint in the project's Sprint settings soon." ;;
esac

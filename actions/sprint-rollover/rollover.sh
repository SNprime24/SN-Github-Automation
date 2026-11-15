#!/usr/bin/env bash
# At the start of a sprint, moves unfinished cards to Backlog in the next sprint
# (the first one that starts after today):
#   - cards in Todo from the current sprint or an earlier one
#   - cards in Backlog from the current sprint
# Left alone: other columns, cards with no Sprint, cards in a future sprint, and
# Backlog cards in an earlier sprint. Each moved issue in OWNER's own repos gets
# a "Rolled over from <sprint>" comment.
# Called by action.yml.
#
# Environment (set by action.yml):
#   GH_TOKEN              classic token with the repo and project scopes
#   OWNER                 login of the user that owns the project
#   PROJECT_NUMBER        project number, from its URL
#   SPRINT_TZ             timezone for "today"
#   AS_OF                 optional YYYY-MM-DD to use instead of today
#   DRY_RUN               "true" to only list the cards that would move
#   ONLY_ON_SPRINT_START  "true" to do nothing unless a sprint starts today
#                         (set for scheduled runs)

# The $names inside the single-quoted queries are GraphQL or jq variables, not shell ones.
# shellcheck disable=SC2016

set -euo pipefail
# shellcheck source=lib/board.sh
source "$(dirname "${BASH_SOURCE[0]}")/../../lib/board.sh"

today=${AS_OF:-$(TZ="$SPRINT_TZ" date +%F)}

project=$(board_project "$OWNER" "$PROJECT_NUMBER")

# The Sprint iteration that today falls in: it started on or before today and
# hasn't ended yet. Dates are compared as midnight UTC, and durations are in days.
current_sprint=$(jq -c --arg today "$today" '
  ($today + "T00:00:00Z" | fromdate) as $now
  | [.fields.nodes[] | select(.name == "Sprint") | .configuration.iterations[]
     | (.startDate + "T00:00:00Z" | fromdate) as $start
     | select($start <= $now and $now < $start + .duration * 86400)]
  | .[0] // empty' <<<"$project")
if [[ -z "$current_sprint" ]]; then
  echo "::error::No sprint is running on $today, so nothing was rolled over. Add a sprint in the project's Sprint settings, then run this workflow by hand."
  exit 1
fi
current_title=$(jq -r .title <<<"$current_sprint")
sprint_start=$(jq -r .startDate <<<"$current_sprint")

if [[ "$ONLY_ON_SPRINT_START" == true && "$sprint_start" != "$today" ]]; then
  echo "$current_title started on $sprint_start, not today ($today), so there is nothing to roll over"
  exit 0
fi

next_sprint=$(board_upcoming_sprints "$project" "$today" | jq -c '.[0] // empty')
if [[ -z "$next_sprint" ]]; then
  echo "::error::No sprint starts after $today, so nothing was rolled over. Add a sprint in the project's Sprint settings, then run this workflow by hand."
  exit 1
fi
next_title=$(jq -r .title <<<"$next_sprint")

project_id=$(jq -r .id <<<"$project")
status_field=$(board_field_id "$project" Status)
backlog=$(board_option_id "$project" Status Backlog)
sprint_field=$(board_field_id "$project" Sprint)
iteration=$(jq -r .id <<<"$next_sprint")
if [[ -z "$status_field" || -z "$backlog" || -z "$sprint_field" ]]; then
  echo "::error::The Status field, its Backlog option or the Sprint field is missing from the board"
  exit 1
fi

# Every card, with what it is, its Status and its Sprint.
items_query='
  query($login: String!, $number: Int!, $endCursor: String) {
    user(login: $login) { projectV2(number: $number) {
      items(first: 100, after: $endCursor) {
        pageInfo { hasNextPage endCursor }
        nodes {
          id isArchived
          content {
            ... on Issue { id url }
            ... on PullRequest { url }
            ... on DraftIssue { title }
          }
          status: fieldValueByName(name: "Status") { ... on ProjectV2ItemFieldSingleSelectValue { name } }
          sprint: fieldValueByName(name: "Sprint") { ... on ProjectV2ItemFieldIterationValue { title startDate } }
        }
      }
    } }
  }'

# One line per card to move:
#   item ID <tab> its status <tab> its sprint <tab> issue ID, or - if it isn't an issue <tab> link, or title for a draft
cards_filter='
  .data.user.projectV2.items.nodes[]
  | select(.isArchived | not)
  | select(.sprint.startDate)
  # Todo from the current sprint or an earlier one, or Backlog from the current sprint.
  | select((.status.name == "Todo" and .sprint.startDate <= $start)
           or (.status.name == "Backlog" and .sprint.startDate == $start))
  | [.id, .status.name, .sprint.title, (.content.id // "-"), (.content.url // .content.title)]
  | @tsv'

cards=$(gh api graphql --paginate -f query="$items_query" -f login="$OWNER" -F number="$PROJECT_NUMBER" \
  | jq -r --arg start "$sprint_start" "$cards_filter")

moved=0
while IFS=$'\t' read -r item old_status old_sprint issue card; do
  [[ -z "$item" ]] && continue
  if [[ "$DRY_RUN" == true ]]; then
    echo "Would move $card ($old_status, $old_sprint) to Backlog in $next_title"
  else
    board_set_option "$project_id" "$item" "$status_field" "$backlog"
    board_set_iteration "$project_id" "$item" "$sprint_field" "$iteration"
    echo "Moved $card ($old_status, $old_sprint) to Backlog in $next_title"
    # Comments notify people, so only issues in OWNER's own repos get one.
    if [[ "$issue" != - && "$card" == "https://github.com/$OWNER/"* ]]; then
      gh api graphql -f query='
        mutation($issue: ID!, $body: String!) {
          addComment(input: {subjectId: $issue, body: $body}) { clientMutationId }
        }' -f issue="$issue" -f body="Rolled over from $old_sprint" --silent \
        || echo "::warning::Couldn't comment on $card"
    fi
  fi
  moved=$((moved + 1))
done <<<"$cards"

if [[ "$DRY_RUN" == true ]]; then
  echo "Dry run: would move $moved cards to Backlog in $next_title"
else
  echo "Moved $moved cards to Backlog in $next_title"
fi

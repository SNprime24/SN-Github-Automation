#!/usr/bin/env bash
# Moves Todo cards from the current or an earlier sprint, and Backlog cards from the current sprint, to Backlog in the next sprint.
# shellcheck disable=SC2016 # the $names inside the queries and filters are GraphQL and jq variables

set -euo pipefail
# shellcheck source=lib/board.sh
source "$(dirname "${BASH_SOURCE[0]}")/../../lib/board.sh"

today=${AS_OF:-$(TZ="$SPRINT_TZ" date +%F)}
project=$(board_project "$OWNER" "$PROJECT_NUMBER")

# The sprint that today falls in: started on or before today, and its duration in days hasn't passed
current_sprint=$(jq -c --arg today "$today" '
  ($today + "T00:00:00Z" | fromdate) as $now
  | [.fields.nodes[] | select(.name == "Sprint") | .configuration.iterations[]
     | (.startDate + "T00:00:00Z" | fromdate) as $start
     | select($start <= $now and $now < $start + .duration * 86400)]
  | .[0] // empty' <<<"$project")
if [[ -z $current_sprint ]]; then
  echo "::error::No sprint is running on $today, so nothing was rolled over. Add a sprint in the project's Sprint settings, then run this workflow by hand."
  exit 1
fi
current_title=$(jq -r .title <<<"$current_sprint")
sprint_start=$(jq -r .startDate <<<"$current_sprint")

if [[ $ONLY_ON_SPRINT_START == true && $sprint_start != "$today" ]]; then
  echo "$current_title started on $sprint_start, not today ($today), so there is nothing to roll over"
  exit 0
fi

next_sprint=$(board_upcoming_sprints "$project" "$today" | jq -c '.[0] // empty')
if [[ -z $next_sprint ]]; then
  echo "::error::No sprint starts after $today, so nothing was rolled over. Add a sprint in the project's Sprint settings, then run this workflow by hand."
  exit 1
fi
next_title=$(jq -r .title <<<"$next_sprint")
next_iteration=$(jq -r .id <<<"$next_sprint")

project_id=$(jq -r .id <<<"$project")
status_field=$(board_field_id "$project" Status)
backlog=$(board_option_id "$project" Status Backlog)
sprint_field=$(board_field_id "$project" Sprint)
if [[ -z $status_field || -z $backlog || -z $sprint_field ]]; then
  echo "::error::The Status field, its Backlog option or the Sprint field is missing from the board"
  exit 1
fi

cards_query='
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

# One line per card to move: item ID, status, sprint, issue ID (- if not an issue), link (or a draft's title)
cards_to_move_filter='
  .data.user.projectV2.items.nodes[]
  | select((.isArchived | not) and .sprint.startDate)
  | select((.status.name == "Todo" and .sprint.startDate <= $start)
           or (.status.name == "Backlog" and .sprint.startDate == $start))
  | [.id, .status.name, .sprint.title, (.content.id // "-"), (.content.url // .content.title)]
  | @tsv'

comment_on_issue() {
  gh api graphql -f query='
    mutation($issue: ID!, $body: String!) {
      addComment(input: {subjectId: $issue, body: $body}) { clientMutationId }
    }' -f issue="$1" -f body="$2" --silent
}

cards=$(gh api graphql --paginate -f query="$cards_query" -f login="$OWNER" -F number="$PROJECT_NUMBER" \
  | jq -r --arg start "$sprint_start" "$cards_to_move_filter")

moved=0
while IFS=$'\t' read -r item old_status old_sprint issue card; do
  [[ -z $item ]] && continue
  moved=$((moved + 1))
  if [[ $DRY_RUN == true ]]; then
    echo "Would move $card ($old_status, $old_sprint) to Backlog in $next_title"
    continue
  fi
  board_set_option "$project_id" "$item" "$status_field" "$backlog"
  board_set_iteration "$project_id" "$item" "$sprint_field" "$next_iteration"
  echo "Moved $card ($old_status, $old_sprint) to Backlog in $next_title"
  # Comments notify people, so only issues in the owner's own repos get one.
  if [[ $issue != - && $card == "https://github.com/$OWNER/"* ]]; then
    comment_on_issue "$issue" "Rolled over from $old_sprint" || echo "::warning::Couldn't comment on $card"
  fi
done <<<"$cards"

if [[ $DRY_RUN == true ]]; then
  echo "Dry run: would move $moved cards to Backlog in $next_title"
else
  echo "Moved $moved cards to Backlog in $next_title"
fi

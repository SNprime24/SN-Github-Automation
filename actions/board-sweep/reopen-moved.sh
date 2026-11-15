#!/usr/bin/env bash
# Reopens closed issues whose card was moved out of Done after they closed, then puts each card back in its column.
# shellcheck disable=SC2016 # the $names inside the queries and filters are GraphQL and jq variables

set -euo pipefail
# shellcheck source=lib/board.sh
source "$(dirname "${BASH_SOURCE[0]}")/../../lib/board.sh"

project_id=$(board_project "$OWNER" "$PROJECT_NUMBER" | jq -r .id)

cards_query='
  query($login: String!, $number: Int!, $endCursor: String) {
    user(login: $login) { projectV2(number: $number) {
      items(first: 100, after: $endCursor) {
        pageInfo { hasNextPage endCursor }
        nodes {
          id isArchived
          content { ... on Issue { id url state closedAt viewerCanReopen } }
          fieldValueByName(name: "Status") { ... on ProjectV2ItemFieldSingleSelectValue {
            name optionId field { ... on ProjectV2SingleSelectField { id } }
          } }
        }
      }
    } }
  }'

# One line per closed issue whose card isn't in Done: item, issue, url, closed at, can reopen, status, its option and field
closed_not_done_filter='
  .data.user.projectV2.items.nodes[]
  | select((.isArchived | not) and .content.state == "CLOSED" and .fieldValueByName.name != "Done")
  | [.id, .content.id, .content.url, .content.closedAt, .content.viewerCanReopen,
     (.fieldValueByName.name // "no status"), (.fieldValueByName.optionId // "-"), (.fieldValueByName.field.id // "-")]
  | @tsv'

# ISSUE_ID CLOSED_AT -> how often its card on this board left Done after the issue closed
moves_out_of_done() {
  gh api graphql -f query='
    query($id: ID!) {
      node(id: $id) { ... on Issue {
        timelineItems(last: 50, itemTypes: [PROJECT_V2_ITEM_STATUS_CHANGED_EVENT]) { nodes {
          ... on ProjectV2ItemStatusChangedEvent { createdAt previousStatus project { id } }
        } }
      } }
    }' -f id="$1" --jq '.data.node.timelineItems.nodes' \
    | jq --arg project "$project_id" --arg closed "$2" \
      '[.[] | select(.project.id == $project and .previousStatus == "Done" and .createdAt > $closed)] | length'
}

reopen_issue() {
  gh api graphql -f query='
    mutation($issue: ID!) {
      reopenIssue(input: {issueId: $issue}) { issue { id } }
    }' -f issue="$1" --silent
}

candidates=$(gh api graphql --paginate -f query="$cards_query" -f login="$OWNER" -F number="$PROJECT_NUMBER" \
  --jq "$closed_not_done_filter")

reopened=0
columns_to_restore=()
while IFS=$'\t' read -r item issue url closed_at can_reopen status option field; do
  [[ -z $item ]] && continue
  moves=$(moves_out_of_done "$issue" "$closed_at")
  if [[ $moves == 0 ]]; then
    echo "Left closed: $url is in '$status' but wasn't moved out of Done after it closed"
    continue
  fi
  if [[ $can_reopen != true ]]; then
    echo "::warning::Can't reopen $url: BOARD_TOKEN has no write access to that repo"
    continue
  fi
  reopen_issue "$issue"
  echo "Reopened $url (card is in '$status')"
  reopened=$((reopened + 1))
  if [[ $option != - ]]; then
    columns_to_restore+=("$item $field $option")
  fi
done <<<"$candidates"
echo "Reopened $reopened issues"

# The board's "Item reopened" workflow moves reopened cards to Todo; wait for it, then undo that.
if ((${#columns_to_restore[@]})); then
  sleep "${REOPEN_SETTLE_SECONDS:-30}"
  for entry in "${columns_to_restore[@]}"; do
    read -r item field option <<<"$entry"
    board_set_option "$project_id" "$item" "$field" "$option"
  done
fi

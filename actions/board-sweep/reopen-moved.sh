#!/usr/bin/env bash
# Reopens closed issues whose card was moved out of Done after the issue closed,
# then puts each card back in the column it was moved to.
# Called by action.yml.
#
# Environment (set by action.yml):
#   GH_TOKEN               classic token with the repo and project scopes
#   OWNER                  login of the user that owns the project
#   PROJECT_NUMBER         project number, from its URL
#   REOPEN_SETTLE_SECONDS  optional, default 30: how long to wait for the board's own
#                          "Item reopened" workflow before restoring the columns.
#                          The tests set it to 0.

# The $names inside the single-quoted queries are GraphQL or jq variables, not shell ones.
# shellcheck disable=SC2016

set -euo pipefail
# shellcheck source=lib/board.sh
source "$(dirname "${BASH_SOURCE[0]}")/../../lib/board.sh"

project_id=$(board_project "$OWNER" "$PROJECT_NUMBER" | jq -r .id)

# Every card, with its issue (if it is one) and its Status.
items_query='
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

# One line per closed issue whose card isn't archived and isn't in Done:
#   item, issue, url, closed at, can reopen, status name, status option, status field
candidates_filter='
  .data.user.projectV2.items.nodes[]
  | select((.isArchived | not) and .content.state == "CLOSED" and .fieldValueByName.name != "Done")
  | [.id, .content.id, .content.url, .content.closedAt, .content.viewerCanReopen,
     .fieldValueByName.name, .fieldValueByName.optionId, .fieldValueByName.field.id]
  | @tsv'

# The issue's last 50 Status changes on any board.
status_changes_query='
  query($id: ID!) {
    node(id: $id) { ... on Issue {
      timelineItems(last: 50, itemTypes: [PROJECT_V2_ITEM_STATUS_CHANGED_EVENT]) { nodes {
        ... on ProjectV2ItemStatusChangedEvent { createdAt previousStatus project { id } }
      } }
    } }
  }'

# How many of those moved the card out of Done on this board after the issue closed.
moves_out_of_done_filter='
  [.[] | select(.project.id == $project and .previousStatus == "Done" and .createdAt > $closed)]
  | length'

candidates=$(gh api graphql --paginate -f query="$items_query" -f login="$OWNER" -F number="$PROJECT_NUMBER" \
  --jq "$candidates_filter")

reopened=0
restore=()
while IFS=$'\t' read -r item issue url closed_at can_reopen status option field; do
  [[ -z "$item" ]] && continue

  # Only a move out of Done after the issue was closed counts, so a card
  # that simply never reached Done doesn't get its issue reopened.
  moved=$(gh api graphql -f query="$status_changes_query" -f id="$issue" --jq '.data.node.timelineItems.nodes' \
    | jq --arg project "$project_id" --arg closed "$closed_at" "$moves_out_of_done_filter")

  if [[ "$moved" == 0 ]]; then
    echo "Left closed: $url is in '$status' but wasn't moved out of Done after it closed"
    continue
  fi
  if [[ "$can_reopen" != true ]]; then
    echo "::warning::Can't reopen $url: BOARD_TOKEN has no write access to that repo"
    continue
  fi

  gh api graphql -f query='
    mutation($issue: ID!) {
      reopenIssue(input: {issueId: $issue}) { issue { id } }
    }' -f issue="$issue" --silent
  echo "Reopened $url (card is in '$status')"
  reopened=$((reopened + 1))
  if [[ -n "$option" ]]; then
    restore+=("$item $option $field")
  fi
done <<<"$candidates"

echo "Reopened $reopened issues"

# The board's built-in "Item reopened" workflow moves the card to Todo. Give it
# time to run, then put the card back in the column it was moved to.
if ((${#restore[@]} > 0)); then
  sleep "${REOPEN_SETTLE_SECONDS:-30}"
  for entry in "${restore[@]}"; do
    read -r item option field <<<"$entry"
    board_set_option "$project_id" "$item" "$field" "$option"
  done
fi

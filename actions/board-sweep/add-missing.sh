#!/usr/bin/env bash
# Adds every open issue in the owner's repos, and open issues assigned to the owner elsewhere, to the board.
# shellcheck disable=SC2016 # the $names inside the query are GraphQL variables

set -euo pipefail
# shellcheck source=lib/board.sh
source "$(dirname "${BASH_SOURCE[0]}")/../../lib/board.sh"

project_id=$(board_project "$OWNER" "$PROJECT_NUMBER" | jq -r .id)

add_to_board() {
  gh api graphql -f query='
    mutation($project: ID!, $content: ID!) {
      addProjectV2ItemById(input: {projectId: $project, contentId: $content}) { item { id } }
    }' -f project="$project_id" -f content="$1" --silent
}

repos=$(gh repo list "$OWNER" --source --no-archived --limit 500 \
  --json name,hasIssuesEnabled --jq '.[] | select(.hasIssuesEnabled) | .name')

checked=0
for repo in $repos; do
  if [[ " $SKIP_REPOS " == *" $repo "* ]]; then
    echo "Skipping $repo"
    continue
  fi
  for issue in $(gh issue list -R "$OWNER/$repo" --state open --limit 500 --json id --jq '.[].id'); do
    add_to_board "$issue"
    checked=$((checked + 1))
  done
done
echo "Checked $checked open issues across $(wc -w <<<"$repos") repos"

assigned=0
for issue in $(gh search issues --assignee "$OWNER" --state open --limit 500 --json id,repository \
  --jq ".[] | select(.repository.nameWithOwner | startswith(\"$OWNER/\") | not) | .id"); do
  add_to_board "$issue"
  assigned=$((assigned + 1))
done
echo "Checked $assigned open issues assigned to $OWNER in repos owned by others"

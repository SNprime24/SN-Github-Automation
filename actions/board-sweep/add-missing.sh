#!/usr/bin/env bash
# Adds every open issue in OWNER's repos to the board, then the open issues
# assigned to OWNER in repos owned by others. Forks, archived repos, repos with
# issues turned off and the repos in SKIP_REPOS are left out. Adding an issue
# that's already on the board does nothing, so reruns are safe.
# Called by action.yml.
#
# Environment (set by action.yml):
#   GH_TOKEN        classic token with the repo and project scopes
#   OWNER           login of the user that owns the project and the repos
#   PROJECT_NUMBER  project number, from its URL
#   SKIP_REPOS      space-separated repo names to keep off the board

# The $names inside the single-quoted queries are GraphQL variables, not shell ones.
# shellcheck disable=SC2016

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
  for issue_id in $(gh issue list -R "$OWNER/$repo" --state open --limit 500 --json id --jq '.[].id'); do
    add_to_board "$issue_id"
    checked=$((checked + 1))
  done
done

echo "Checked $checked open issues across $(echo "$repos" | wc -w) repos"

# Issues assigned to OWNER in other people's repos (friends, orgs they contribute to).
assigned=0
for issue_id in $(gh search issues --assignee "$OWNER" --state open --limit 500 \
    --json id,repository --jq ".[] | select(.repository.nameWithOwner | startswith(\"$OWNER/\") | not) | .id"); do
  add_to_board "$issue_id"
  assigned=$((assigned + 1))
done

echo "Checked $assigned open issues assigned to $OWNER in repos owned by others"

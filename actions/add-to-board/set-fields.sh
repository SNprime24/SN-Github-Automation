#!/usr/bin/env bash
# Fills empty Priority / Size / Status fields on a project item with the board
# defaults, then an empty Sprint with the next sprint.
# Called by action.yml after actions/add-to-project has added the card.
#
# Environment (set by action.yml):
#   GH_TOKEN        classic token with the repo and project scopes
#   ITEM_ID         project item ID returned by actions/add-to-project
#   OWNER           login of the user that owns the project
#   PROJECT_NUMBER  project number, from its URL
#   DEFAULTS        space-separated Field=Option pairs; only empty fields are filled
#   SPRINT_TZ       timezone for "today" when picking the next sprint
set -euo pipefail

project=$(gh api graphql -f query='
  query($login: String!, $number: Int!) {
    user(login: $login) { projectV2(number: $number) {
      id
      fields(first: 50) { nodes {
        ... on ProjectV2SingleSelectField { id name options { id name } }
        ... on ProjectV2IterationField { id name configuration { iterations { id title startDate } } }
      } }
    } }
  }' -f login="$OWNER" -F number="$PROJECT_NUMBER" --jq '.data.user.projectV2')

filled=$(gh api graphql -f query='
  query($id: ID!) {
    node(id: $id) { ... on ProjectV2Item {
      fieldValues(first: 30) { nodes {
        ... on ProjectV2ItemFieldSingleSelectValue { field { ... on ProjectV2SingleSelectField { name } } }
        ... on ProjectV2ItemFieldIterationValue { field { ... on ProjectV2IterationField { name } } }
      } }
    } }
  }' -f id="$ITEM_ID" --jq '[.data.node.fieldValues.nodes[].field.name // empty] | join(",")')

for pair in $DEFAULTS; do
  name=${pair%%=*}
  option=${pair#*=}
  if [[ ",$filled," == *",$name,"* ]]; then
    echo "$name already set"
    continue
  fi
  field_id=$(jq -r --arg n "$name" '.fields.nodes[] | select(.name == $n) | .id' <<<"$project")
  option_id=$(jq -r --arg n "$name" --arg o "$option" '.fields.nodes[] | select(.name == $n) | .options[] | select(.name == $o) | .id' <<<"$project")
  if [[ -z "$field_id" || -z "$option_id" ]]; then
    echo "::warning::Field '$name' or option '$option' not found on the board"
    continue
  fi
  gh api graphql -f query='
    mutation($project: ID!, $item: ID!, $field: ID!, $option: String!) {
      updateProjectV2ItemFieldValue(input: {projectId: $project, itemId: $item, fieldId: $field,
        value: {singleSelectOptionId: $option}}) { projectV2Item { id } }
    }' -f project="$(jq -r .id <<<"$project")" -f item="$ITEM_ID" \
       -f field="$field_id" -f option="$option_id" --silent
  echo "Set $name = $option"
done

if [[ ",$filled," == *",Sprint,"* ]]; then
  echo "Sprint already set"
  exit 0
fi
today=$(TZ="$SPRINT_TZ" date +%F)
sprint_field=$(jq -r '.fields.nodes[] | select(.name == "Sprint") | .id' <<<"$project")
next_sprint=$(jq -c --arg today "$today" '[.fields.nodes[] | select(.name == "Sprint") | .configuration.iterations[] | select(.startDate > $today)] | sort_by(.startDate) | .[0] // empty' <<<"$project")
if [[ -z "$next_sprint" ]]; then
  echo "::warning::No sprint starts after $today, so Sprint was left empty. Add one in the project's Sprint settings; the daily sweep then fills recent cards."
  exit 0
fi
gh api graphql -f query='
  mutation($project: ID!, $item: ID!, $field: ID!, $iteration: String!) {
    updateProjectV2ItemFieldValue(input: {projectId: $project, itemId: $item, fieldId: $field,
      value: {iterationId: $iteration}}) { projectV2Item { id } }
  }' -f project="$(jq -r .id <<<"$project")" -f item="$ITEM_ID" \
     -f field="$sprint_field" -f iteration="$(jq -r .id <<<"$next_sprint")" --silent
echo "Set Sprint = $(jq -r .title <<<"$next_sprint")"

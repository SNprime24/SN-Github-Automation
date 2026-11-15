#!/usr/bin/env bash
# Shared helpers for the board scripts. Source this file; it defines functions
# only. Needs gh and jq, with GH_TOKEN set to a classic token with the repo and
# project scopes.

# The $names inside the single-quoted queries are GraphQL variables, not shell ones.
# shellcheck disable=SC2016

# board_project OWNER NUMBER
# Prints the project as JSON: its id and its single-select and iteration fields,
# with their options and iterations. Other field types come back as {}.
board_project() {
  gh api graphql -f query='
    query($login: String!, $number: Int!) {
      user(login: $login) { projectV2(number: $number) {
        id
        fields(first: 50) { nodes {
          ... on ProjectV2SingleSelectField { id name options { id name } }
          ... on ProjectV2IterationField { id name configuration { iterations { id title startDate duration } } }
        } }
      } }
    }' -f login="$1" -F number="$2" --jq '.data.user.projectV2'
}

# board_field_id PROJECT_JSON FIELD
# Prints the field's ID, or nothing if the board has no such field.
board_field_id() {
  jq -r --arg n "$2" '.fields.nodes[] | select(.name == $n) | .id' <<<"$1"
}

# board_option_id PROJECT_JSON FIELD OPTION
# Prints the ID of an option of a single-select field, or nothing if either is missing.
board_option_id() {
  jq -r --arg n "$2" --arg o "$3" \
    '.fields.nodes[] | select(.name == $n) | .options[] | select(.name == $o) | .id' <<<"$1"
}

# board_upcoming_sprints PROJECT_JSON TODAY
# Prints a JSON array of the Sprint iterations that start after TODAY
# (YYYY-MM-DD), earliest first. The first one is "the next sprint".
board_upcoming_sprints() {
  jq -c --arg today "$2" '
    [.fields.nodes[] | select(.name == "Sprint") | .configuration.iterations[] | select(.startDate > $today)]
    | sort_by(.startDate)' <<<"$1"
}

# board_set_option PROJECT_ID ITEM_ID FIELD_ID OPTION_ID
# Sets a single-select field on a card.
board_set_option() {
  gh api graphql -f query='
    mutation($project: ID!, $item: ID!, $field: ID!, $option: String!) {
      updateProjectV2ItemFieldValue(input: {projectId: $project, itemId: $item, fieldId: $field,
        value: {singleSelectOptionId: $option}}) { projectV2Item { id } }
    }' -f project="$1" -f item="$2" -f field="$3" -f option="$4" --silent
}

# board_set_iteration PROJECT_ID ITEM_ID FIELD_ID ITERATION_ID
# Sets an iteration field, such as Sprint, on a card.
board_set_iteration() {
  gh api graphql -f query='
    mutation($project: ID!, $item: ID!, $field: ID!, $iteration: String!) {
      updateProjectV2ItemFieldValue(input: {projectId: $project, itemId: $item, fieldId: $field,
        value: {iterationId: $iteration}}) { projectV2Item { id } }
    }' -f project="$1" -f item="$2" -f field="$3" -f iteration="$4" --silent
}

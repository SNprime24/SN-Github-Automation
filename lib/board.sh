#!/usr/bin/env bash
# Project board helpers shared by the action scripts; they need gh, jq and GH_TOKEN.
# shellcheck disable=SC2016 # the $names inside the queries are GraphQL variables

# OWNER NUMBER -> the project as JSON, with its single-select and iteration fields
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

# PROJECT_JSON FIELD
board_field_id() {
  jq -r --arg n "$2" '.fields.nodes[] | select(.name == $n) | .id' <<<"$1"
}

# PROJECT_JSON FIELD OPTION
board_option_id() {
  jq -r --arg n "$2" --arg o "$3" '.fields.nodes[] | select(.name == $n) | .options[] | select(.name == $o) | .id' <<<"$1"
}

# PROJECT_JSON TODAY -> the Sprint iterations that start after TODAY, earliest first
board_upcoming_sprints() {
  jq -c --arg today "$2" '
    [.fields.nodes[] | select(.name == "Sprint") | .configuration.iterations[] | select(.startDate > $today)]
    | sort_by(.startDate)' <<<"$1"
}

# ITEM_ID -> the names of the card's set fields, comma-separated
board_filled_fields() {
  gh api graphql -f query='
    query($id: ID!) {
      node(id: $id) { ... on ProjectV2Item {
        fieldValues(first: 30) { nodes {
          ... on ProjectV2ItemFieldSingleSelectValue { field { ... on ProjectV2SingleSelectField { name } } }
          ... on ProjectV2ItemFieldIterationValue { field { ... on ProjectV2IterationField { name } } }
        } }
      } }
    }' -f id="$1" --jq '[.data.node.fieldValues.nodes[].field.name // empty] | join(",")'
}

# FILLED_FIELDS NAME
has_field() {
  [[ ",$1," == *",$2,"* ]]
}

# PROJECT_ID ITEM_ID FIELD_ID OPTION_ID
board_set_option() {
  gh api graphql -f query='
    mutation($project: ID!, $item: ID!, $field: ID!, $option: String!) {
      updateProjectV2ItemFieldValue(input: {projectId: $project, itemId: $item, fieldId: $field,
        value: {singleSelectOptionId: $option}}) { projectV2Item { id } }
    }' -f project="$1" -f item="$2" -f field="$3" -f option="$4" --silent
}

# PROJECT_ID ITEM_ID FIELD_ID ITERATION_ID
board_set_iteration() {
  gh api graphql -f query='
    mutation($project: ID!, $item: ID!, $field: ID!, $iteration: String!) {
      updateProjectV2ItemFieldValue(input: {projectId: $project, itemId: $item, fieldId: $field,
        value: {iterationId: $iteration}}) { projectV2Item { id } }
    }' -f project="$1" -f item="$2" -f field="$3" -f iteration="$4" --silent
}

# PROJECT_JSON DEFAULTS -> resolved_defaults holds "name field_id option_id" for each Field=Option the board has
board_resolve_defaults() {
  local pair name option field_id option_id
  resolved_defaults=()
  for pair in $2; do
    name=${pair%%=*}
    option=${pair#*=}
    field_id=$(board_field_id "$1" "$name")
    option_id=$(board_option_id "$1" "$name" "$option")
    if [[ -z $field_id || -z $option_id ]]; then
      echo "::warning::Field '$name' or option '$option' not found on the board"
      continue
    fi
    resolved_defaults+=("$name $field_id $option_id")
  done
}

# PROJECT_ID ITEM_ID FILLED_FIELDS -> sets each resolved default the card doesn't have yet and prints how many
board_fill_defaults() {
  local entry name field option count=0
  for entry in "${resolved_defaults[@]}"; do
    read -r name field option <<<"$entry"
    if ! has_field "$3" "$name"; then
      board_set_option "$1" "$2" "$field" "$option"
      count=$((count + 1))
    fi
  done
  echo "$count"
}

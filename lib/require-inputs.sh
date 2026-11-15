#!/usr/bin/env bash
# Fails with an error per empty input; arguments are env var names, e.g. PROJECT_NUMBER for the project-number input.

status=0
for var in "$@"; do
  if [[ -z ${!var:-} ]]; then
    input=${var,,}
    echo "::error::The ${input//_/-} input is required"
    status=1
  fi
done
exit "$status"

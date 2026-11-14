#!/usr/bin/env bash
# Stand-in for `gh api graphql`, used by test-set-fields.sh.
# - The project query returns $FAKE_GH_DIR/project.json.
# - The item query returns $FAKE_GH_DIR/item.json.
# - Each mutation appends its variables (except the query) as one line to $FAKE_GH_DIR/mutations.log.
# --jq is applied with the real jq, like gh does.
set -euo pipefail

if [[ "${1-} ${2-}" != "api graphql" ]]; then
  echo "fake gh: only 'gh api graphql' is supported, got: $*" >&2
  exit 1
fi
shift 2

query=""
jq_filter=""
vars=()
while (($#)); do
  case $1 in
    -f | -F)
      case $2 in
        query=*) query=${2#query=} ;;
        *) vars+=("$2") ;;
      esac
      shift 2
      ;;
    --jq)
      jq_filter=$2
      shift 2
      ;;
    --silent) shift ;;
    *)
      echo "fake gh: unexpected argument: $1" >&2
      exit 1
      ;;
  esac
done

case $query in
  *updateProjectV2ItemFieldValue*)
    printf '%s\n' "${vars[*]}" >>"$FAKE_GH_DIR/mutations.log"
    response='{"data":{"updateProjectV2ItemFieldValue":{"projectV2Item":{"id":"ITEM"}}}}'
    ;;
  *'projectV2(number:'*) response=$(<"$FAKE_GH_DIR/project.json") ;;
  *'node(id:'*) response=$(<"$FAKE_GH_DIR/item.json") ;;
  *)
    echo "fake gh: unknown query: $query" >&2
    exit 1
    ;;
esac

if [[ -n $jq_filter ]]; then
  jq -r "$jq_filter" <<<"$response"
fi

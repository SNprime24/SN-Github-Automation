#!/usr/bin/env bash
# Stand-in for gh: answers from files in $FAKE_GH_DIR and logs each change as "<kind> <variables>" to calls.log.
set -euo pipefail

dir=$FAKE_GH_DIR
jq_filter=""
silent=0

read_or() {
  if [[ -e $1 ]]; then cat "$1"; else printf '%s\n' "$2"; fi
}

command="${1-} ${2-}"
shift 2 || true

if [[ $command == "api graphql" ]]; then
  query=""
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
      --silent)
        silent=1
        shift
        ;;
      --paginate) shift ;;
      *)
        echo "fake gh: unexpected argument: $1" >&2
        exit 1
        ;;
    esac
  done

  log() { printf '%s %s\n' "$1" "${vars[*]}" >>"$dir/calls.log"; }
  node_id=""
  for var in "${vars[@]}"; do
    [[ $var == id=* ]] && node_id=${var#id=}
  done

  case $query in
    *addProjectV2ItemById*) log add && response='{}' ;;
    *updateProjectV2ItemFieldValue*) log set && response='{}' ;;
    *reopenIssue*) log reopen && response='{}' ;;
    *addComment*)
      log comment
      if [[ -e $dir/fail-comment ]]; then
        echo "fake gh: comment failed" >&2
        exit 1
      fi
      response='{}'
      ;;
    *timelineItems*) response=$(read_or "$dir/timeline/$node_id.json" '{"data":{"node":{"timelineItems":{"nodes":[]}}}}') ;;
    *'on ProjectV2Item {'*) response=$(<"$dir/item.json") ;;
    *viewerCanReopen*) response=$(<"$dir/closed.json") ;;
    *DraftIssue*) response=$(<"$dir/cards.json") ;;
    *fieldValues*) response=$(<"$dir/items.json") ;;
    *'fields(first:'*) response=$(<"$dir/project.json") ;;
    *)
      echo "fake gh: unknown query: $query" >&2
      exit 1
      ;;
  esac
else
  repo=""
  while (($#)); do
    case $1 in
      --jq)
        jq_filter=$2
        shift 2
        ;;
      -R)
        repo=${2#*/}
        shift 2
        ;;
      *) shift ;;
    esac
  done
  case $command in
    "repo list") response=$(<"$dir/repos.json") ;;
    "issue list") response=$(read_or "$dir/issues/$repo.json" '[]') ;;
    "search issues") response=$(read_or "$dir/search.json" '[]') ;;
    *)
      echo "fake gh: unsupported command: gh $command" >&2
      exit 1
      ;;
  esac
fi

if [[ -n $jq_filter ]]; then
  jq -r "$jq_filter" <<<"$response"
elif ((!silent)); then
  printf '%s\n' "$response"
fi

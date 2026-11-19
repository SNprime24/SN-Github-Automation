# sprint-rollover

Run at the start of each sprint. It moves unfinished cards to **Backlog** in the **next sprint**, which is the first iteration that starts after today:

- cards in **Todo** from the current sprint or an earlier one;
- cards in **Backlog** from the current sprint.

Left alone: other columns, cards with no Sprint, cards in a future sprint, archived cards, and Backlog cards from an earlier sprint.

Each moved issue in the owner's own repos gets a "Rolled over from Sprint N" comment. Issues in other people's repos, pull requests and drafts are moved without one, because comments notify people. If a comment fails, the run warns and carries on.

## When it acts

Cron can't count fortnights, so schedule it **weekly** on the weekday sprints start. A **scheduled** run does nothing unless a sprint starts today. Any other run, such as a manual one, skips that check, so it can catch up after a missed day.

The run fails, so GitHub emails the owner, if no sprint is running today, if no sprint starts after today, or if the board has no Status field with a Backlog option or no Sprint field.

## Usage

```yaml
name: Sprint rollover

on:
  schedule:
    - cron: "47 18 * * 4" # just after midnight on sprint-start day, in sprint-tz
  workflow_dispatch:
    inputs:
      as_of:
        description: Act as if today is this date (YYYY-MM-DD). Leave empty for today.
        type: string
        required: false
      dry_run:
        description: Only list the cards that would move
        type: boolean
        default: false

permissions: {}

jobs:
  rollover:
    runs-on: ubuntu-latest
    timeout-minutes: 5
    steps:
      - uses: SNprime24/SN-Github-Automation/actions/sprint-rollover@v2
        with:
          board-token: ${{ secrets.BOARD_TOKEN }}
          owner: your-login
          project-number: 1
          sprint-tz: UTC
          as-of: ${{ inputs.as_of }}
          dry-run: ${{ inputs.dry_run }}
```

The log lists the URLs of the moved cards. Put the caller in a **private** repo if those shouldn't be public.

## Inputs

None have defaults. A missing required input fails the run with an error naming it.

| Input | Required | What it is |
|---|---|---|
| `board-token` | yes | Classic personal access token with the `repo` and `project` scopes, usually `${{ secrets.BOARD_TOKEN }}`. |
| `owner` | yes | Login of the **user** that owns the board. |
| `project-number` | yes | The board's number, from its URL: `https://github.com/users/<owner>/projects/<number>`. |
| `sprint-tz` | yes | Timezone used to decide what "today" is. |
| `as-of` | no | Act as if today is this date, `YYYY-MM-DD`. Empty for today. |
| `dry-run` | no | `true` to only list the cards that would move. Anything else, including empty, moves them. |

## Requirements

- **Runner:** Linux or macOS with `bash`, `gh` and `jq`. GitHub's `ubuntu-latest` runners have all three.
- **Board fields:** a single-select **Status** field with **Todo** and **Backlog** options, and an iteration field named **Sprint**.

## Files

| File | What it is |
|---|---|
| [`action.yml`](action.yml) | Inputs and the steps |
| [`rollover.sh`](rollover.sh) | Finds the cards and moves them |
| [`../../lib/board.sh`](../../lib/board.sh) | Board queries and updates shared with the other actions |
| [`../../tests/sprint-rollover/`](../../tests/sprint-rollover) | Tests for `rollover.sh` with a fake `gh` |

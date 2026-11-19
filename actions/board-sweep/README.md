# board-sweep

A safety net for a GitHub Projects board, meant to run on a schedule (for example twice a day). It catches whatever the [add-to-board](../add-to-board) action missed, and keeps the sprints in check. It runs three steps, in order:

1. **Add missing issues** ([`add-missing.sh`](add-missing.sh)):
   - Adds every open issue in the owner's repos to the board, and open issues assigned to the owner in repos owned by others.
   - Leaves out forks, archived repos, repos with issues turned off, and the repos in `skip-repos`.
   - Adding an issue that's already on the board does nothing, so reruns are safe.
2. **Fill empty fields** ([`fill-defaults.sh`](fill-defaults.sh)):
   - Fills each **empty** single-select field named in `defaults`, on every card that isn't archived. It skips the card of a deleted issue, because nobody can update it.
   - Gives an **empty** Sprint the next sprint, but only on cards added in the last `sprint-fill-days` days that aren't Done.
   - Warns about upcoming sprints that aren't `sprint-length-days` long and when only one is left. **Fails** when none is left, so GitHub emails the owner.
3. **Reopen issues moved out of Done** ([`reopen-moved.sh`](reopen-moved.sh)):
   - Reopens closed issues whose card was moved out of Done **after** the issue closed.
   - The board's built-in "Item reopened" workflow then moves the card to Todo, so after 30 seconds the step puts it back in the column it was moved to.
   - This step runs even when step 2 failed.

Fields that already have a value are never changed.

## Usage

```yaml
name: Board sweep

on:
  schedule:
    - cron: "23 3 * * *"
    - cron: "23 15 * * *"
  workflow_dispatch:

permissions: {}

jobs:
  sweep:
    runs-on: ubuntu-latest
    timeout-minutes: 5
    steps:
      - uses: SNprime24/SN-Github-Automation/actions/board-sweep@v2
        with:
          board-token: ${{ secrets.BOARD_TOKEN }}
          owner: your-login
          project-number: 1
          skip-repos: some-repo another-repo
          defaults: Priority=Normal Size=M Status=Backlog
          sprint-tz: UTC
          sprint-fill-days: 3
          sprint-length-days: 14
```

The log names the skipped repos and the URLs of reopened issues. Run logs are kept in the repo that runs the workflow, so put the caller in a **private** repo if those names shouldn't be public.

## Inputs

None have defaults. A missing required input fails the run with an error naming it.

| Input | Required | What it is |
|---|---|---|
| `board-token` | yes | Classic personal access token with the `repo` and `project` scopes, usually `${{ secrets.BOARD_TOKEN }}`. The `repo` scope lets the sweep see private repos and reopen issues. |
| `owner` | yes | Login of the **user** that owns the board and the repos to sweep. |
| `project-number` | yes | The board's number, from its URL: `https://github.com/users/<owner>/projects/<number>`. |
| `skip-repos` | no | The owner's repos whose issues are kept off the board, separated by spaces. Empty for none. |
| `defaults` | yes | `Field=Option` pairs for single-select fields, separated by spaces. Names must match the board exactly. |
| `sprint-tz` | yes | Timezone used to decide what "today" is when picking the next sprint. |
| `sprint-fill-days` | yes | Only cards added in the last this many days get a Sprint. More than 1, so a skipped run is caught up. |
| `sprint-length-days` | yes | Expected sprint length. Upcoming sprints of another length get a warning. |

## Requirements

- **Runner:** Linux with `bash`, GNU `date`, `gh` and `jq`. GitHub's `ubuntu-latest` runners have them all.
- **Board fields:** Status must be a single-select field with a `Done` option, and Sprint an iteration field named `Sprint`.

## Files

| File | What it is |
|---|---|
| [`action.yml`](action.yml) | Inputs and the steps |
| [`add-missing.sh`](add-missing.sh), [`fill-defaults.sh`](fill-defaults.sh), [`reopen-moved.sh`](reopen-moved.sh) | One script per step |
| [`../../lib/board.sh`](../../lib/board.sh) | Board queries and updates shared with the other actions |
| [`../../tests/board-sweep/`](../../tests/board-sweep) | Tests for the scripts with a fake `gh` |

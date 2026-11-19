# add-to-board

Adds the issue that triggered the workflow to a GitHub Projects board, then fills in the card's empty fields:

1. Adds the card with [`actions/add-to-project`](https://github.com/actions/add-to-project). If the issue is already on the board, it uses the existing card.
2. Fills each **empty** single-select field named in `defaults`.
3. Fills an **empty** Sprint field with the next sprint, which is the first iteration that starts after today.

Fields that already have a value are never changed. If a field or option isn't on the board, or no sprint starts after today, the run logs a warning and carries on.

## Usage

Put this caller in each repo that sends issues to the board, for example as `.github/workflows/add-to-board.yml`:

```yaml
name: Add to board

on:
  issues:
    types: [opened, reopened]

permissions: {}

jobs:
  add:
    runs-on: ubuntu-latest
    timeout-minutes: 2
    steps:
      - uses: SNprime24/SN-Github-Automation/actions/add-to-board@v2
        with:
          board-token: ${{ secrets.BOARD_TOKEN }}
          owner: your-login
          project-number: 1
          defaults: Priority=Normal Size=M Status=Backlog
          sprint-tz: UTC
```

Each repo needs its own `BOARD_TOKEN` secret. If the secret isn't set, the run ends with a notice instead of failing. The [main README](../../README.md#using-the-add-to-board-action) tells how to add the secret and test the caller.

## Inputs

None have defaults. A run with a token and a missing input fails with an error naming it.

| Input | Required | What it is |
|---|---|---|
| `board-token` | no | Classic personal access token with the `repo` and `project` scopes, usually `${{ secrets.BOARD_TOKEN }}`. If it's empty, the action skips with a notice instead of failing. |
| `owner` | yes | Login of the **user** that owns the board. Boards owned by an organization aren't supported. |
| `project-number` | yes | The board's number, from its URL: `https://github.com/users/<owner>/projects/<number>`. |
| `defaults` | yes | `Field=Option` pairs for single-select fields, separated by spaces, for example `Priority=Normal Size=M Status=Backlog`. Names must match the board exactly. |
| `sprint-tz` | yes | Timezone used to decide what "today" is when picking the next sprint, for example `UTC` or `Asia/Kolkata`. |

## Outputs

| Output | What it is |
|---|---|
| `item-id` | ID of the card on the board. Empty when the action skipped, either because there was no token or because the issue was transferred out of the repo. |

## Requirements

- **Runner:** Linux or macOS with `bash`, `gh` and `jq`. GitHub's `ubuntu-latest` runners have all three.
- **Trigger:** an `issues` event, `opened` or `reopened`. An issue transferred into the repo arrives as `opened`. A `transferred` event only reaches the repo the issue left, so the action skips it with a notice.
- **Board fields:** the Sprint field must be an iteration field named `Sprint`.

## Files

| File | What it is |
|---|---|
| [`action.yml`](action.yml) | Inputs, outputs and the steps |
| [`set-fields.sh`](set-fields.sh) | Fills the empty fields and the next sprint |
| [`../../lib/board.sh`](../../lib/board.sh) | Board queries and updates shared with the other actions |
| [`../../tests/add-to-board/`](../../tests/add-to-board) | Tests for `set-fields.sh` with a fake `gh` |

# add-to-board

Adds the issue that triggered the workflow to a GitHub Projects board, then fills in the card's empty fields:

1. Adds the card with [`actions/add-to-project`](https://github.com/actions/add-to-project). If the issue is already on the board, it uses the existing card.
2. Fills each **empty** single-select field named in `defaults` (by default Priority, Size and Status).
3. Fills an **empty** Sprint field with the next sprint, which is the first iteration that starts after today.

Fields that already have a value are never changed. If a field or option isn't on the board, or no sprint starts after today, the run logs a warning and carries on.

See the [main README](../../README.md#using-the-add-to-board-action) for the caller workflow and the `BOARD_TOKEN` secret.

## Inputs

| Input | Default | What it is |
|---|---|---|
| `board-token` | empty | Classic personal access token with the `repo` and `project` scopes, usually `${{ secrets.BOARD_TOKEN }}`. If it's empty, the action skips with a notice instead of failing. |
| `owner` | `SNprime24` | Login of the **user** that owns the board. Boards owned by an organization aren't supported. |
| `project-number` | `13` | The board's number, from its URL: `https://github.com/users/<owner>/projects/<number>`. |
| `defaults` | `Priority=Normal Size=M Status=Backlog` | `Field=Option` pairs for single-select fields, separated by spaces. Field and option names must match the board exactly. |
| `sprint-tz` | The board owner's timezone (see [`action.yml`](action.yml)) | Timezone used to decide what "today" is when picking the next sprint, for example `UTC` or `Europe/Berlin`. |

## Outputs

| Output | What it is |
|---|---|
| `item-id` | ID of the card on the board. Empty when the action skipped because there was no token. |

## Requirements

- **Runner:** Linux or macOS with `bash`, `gh` and `jq`. GitHub's `ubuntu-latest` runners have all three.
- **Trigger:** an `issues` event (`opened`, `reopened` or `transferred`). `actions/add-to-project` reads the issue from the event.
- **Board fields:** the Sprint field must be an iteration field named `Sprint`. Missing fields are skipped with a warning.

## Files

| File | What it is |
|---|---|
| [`action.yml`](action.yml) | Inputs, outputs and the three steps |
| [`set-fields.sh`](set-fields.sh) | Fills the empty fields and the next sprint, using `gh api graphql` |
| [`../../tests/add-to-board/`](../../tests/add-to-board) | Tests for `set-fields.sh` with a fake `gh` |

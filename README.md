# SN-Github-Automation

Shared GitHub Actions workflows and actions that other repositories import, so the logic lives in one place instead of being copied into every repo. The first piece is project-board automation: putting new issues on a GitHub Projects board and filling in default field values.

## What's here

| Name | Kind | What it does |
|---|---|---|
| [`actions/add-to-board`](actions/add-to-board) | Composite action | Adds the issue that triggered the workflow to a project board, then fills empty **Priority**, **Size** and **Status** fields with defaults and an empty **Sprint** with the next sprint. |
| [`add-to-board.yml`](.github/workflows/add-to-board.yml) | Workflow (old copy) | The same logic as a standalone workflow, from before the action existed. Repos that still have a copy keep working, and they move to the action one at a time. It still lists the `transferred` trigger, so transferring an issue **out** of one of those repos shows a failed run there ([#8](https://github.com/SNprime24/SN-Github-Automation/issues/8)). The issue itself still reaches the board from its new repo. |
| [`lint.yml`](.github/workflows/lint.yml) | This repo's CI | Lints the workflows and shell scripts here and tests the add-to-board action, on every pull request and push to `main`. |

## Using the add-to-board action

1. Add a short workflow to the repo, for example `.github/workflows/add-to-board.yml`. Triggers can't be imported, so each repo keeps this file:

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
         - uses: SNprime24/SN-Github-Automation/actions/add-to-board@v1
           with:
             board-token: ${{ secrets.BOARD_TOKEN }}
   ```

2. Add a repository secret named `BOARD_TOKEN` (**Settings → Secrets and variables → Actions**). It must be a **classic** personal access token with the `repo` and `project` scopes.
3. Open a test issue. Within a few seconds it should be on the board with the default values set.

If `BOARD_TOKEN` isn't set, each run ends with a notice instead of failing, so the workflow can be added before the secret.

**Transferred issues** need no trigger of their own. An issue moved into the repo arrives as `opened`, which adds it. Don't add `transferred` to the list. That event only reaches the repo the issue **left**, after the issue has gone, so nothing can be added from there. If a caller still lists it, the action skips it with a notice instead of failing.

The other inputs (which board, which defaults, which timezone) all have defaults, so most callers pass only the token. They're listed in the [action's README](actions/add-to-board/README.md#inputs).

## Versioning

Callers pin to a major version, such as `@v1`, rather than `@main`.

- **Fixes and new options that don't change behaviour** go out as `v1.x.y`. The `v1` tag moves forward to the latest `v1.x.y`, so callers on `@v1` get them automatically.
- **Breaking changes** (renamed or removed inputs, different defaults, different behaviour) go out as `v2`. Callers on `@v1` keep working until they choose to move.

Pinning to `@main` isn't recommended, because a broken commit there would break every caller at once.

## Layout

```text
.github/workflows/   Reusable workflows (on: workflow_call) and this repo's own workflows
actions/<name>/      One composite action per folder: action.yml, its scripts and a short README
tests/<name>/        Tests for the action of the same name
```

New additions go where they fit:

- **A step other workflows can use** → a new folder under `actions/`, named after what it does (for example `actions/add-to-board/`).
- **A whole job other repos call** → a reusable workflow in `.github/workflows/`.

Each new action or workflow also gets a row in [What's here](#whats-here), and its tests a job in `lint.yml`.

## Development

Every pull request runs [`lint.yml`](.github/workflows/lint.yml):

- **actionlint** on the workflows, which also runs shellcheck on their `run:` blocks
- **shellcheck** on the scripts in `actions/` and `tests/`
- **The add-to-board tests:** `set-fields.sh` against a fake `gh` (defaults filled, set fields left alone, unknown fields and options, no future sprint), and the action itself run with no token, to check that it skips

The script tests can also be run locally with bash and jq:

```bash
bash tests/add-to-board/test-set-fields.sh
```

## Requirements

- The repo must be **public** before public repositories can use its actions. Actions in a private repo can only be used by other private repos of the same owner, and only when **Settings → Actions → General → Access** allows it.
- Every repo that uses the board automation needs its own `BOARD_TOKEN` secret. Personal accounts have no shared Actions secrets.

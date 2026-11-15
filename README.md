# SN-Github-Automation

Shared GitHub Actions workflows and actions that other repositories import, so the logic lives in one place instead of being copied into every repo. So far it holds project-board automation: putting new issues on a GitHub Projects board, filling in default field values, and the scheduled jobs that keep the board tidy.

## What's here

| Name | Kind | What it does |
|---|---|---|
| [`actions/add-to-board`](actions/add-to-board) | Composite action | Adds the issue that triggered the workflow to a project board, then fills empty **Priority**, **Size** and **Status** fields with defaults and an empty **Sprint** with the next sprint. |
| [`actions/board-sweep`](actions/board-sweep) | Composite action, scheduled | Safety net: adds open issues that aren't on the board yet, fills empty fields, warns when sprints run out, and reopens closed issues whose card was moved out of Done. |
| [`actions/sprint-rollover`](actions/sprint-rollover) | Composite action, scheduled | At the start of a sprint, moves unfinished Todo and Backlog cards to Backlog in the next sprint. Has a dry run. |
| [`add-to-board.yml`](.github/workflows/add-to-board.yml) | Workflow (old copy) | The same logic as a standalone workflow, from before the action existed. Repos that still have a copy keep working, and they move to the action one at a time. It still lists the `transferred` trigger, so transferring an issue **out** of one of those repos shows a failed run there ([#8](https://github.com/SNprime24/SN-Github-Automation/issues/8)). The issue itself still reaches the board from its new repo. |
| [`plugins/issue-workflow`](plugins/issue-workflow) | Claude Code plugin | Skills that take Claude through an issue: `start-work` (branch + In Progress on the board), `finish-work` (pull request + Review on the board), `create-issue` (makes a clear issue from a short request) and `refine-issue` (turns a rough issue into a clear task). See [Using the Claude Code plugin](#using-the-claude-code-plugin). |
| [`lint.yml`](.github/workflows/lint.yml) | This repo's CI | Lints the workflows and shell scripts here and tests the actions, on every pull request and push to `main`. |

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

## Using the scheduled actions

`board-sweep` and `sprint-rollover` work on the whole board, so they run on a schedule from **one** repo, not from every repo. Each action's README has a caller workflow to copy:

- [board-sweep](actions/board-sweep/README.md#usage), for example twice a day
- [sprint-rollover](actions/sprint-rollover/README.md#usage), weekly on the weekday sprints start

They need the same `BOARD_TOKEN` secret as add-to-board, and unlike add-to-board they **fail** without it, so a missing secret gets noticed.

Their logs name repos and issue URLs, and run logs are kept in the repo that runs the workflow. To keep those private, put the callers in a **private** repo. The actions can still come from this public one.

## Using the Claude Code plugin

This repo is also a Claude Code plugin marketplace. Its `issue-workflow` plugin gives Claude the same way of working in every repo:

| Skill | When | What it does |
|---|---|---|
| `start-work` | Before any code is written for an issue | Reads the issue, creates a branch named `<type>/<repo-initials>-<issue-number>-<short-slug>` (e.g. `feat/sga-24-claude-plugin`), and moves the issue's card to **In Progress** on its board. |
| `finish-work` | Automatically, as soon as the work is done (you can also ask for it) | Commits and pushes, opens a pull request that closes the issue, then moves the card to **Review** on the board. It never merges. |
| `create-issue` | When you need a new issue | Makes a clear issue from a short request, in the same format as `refine-issue`. It looks for a duplicate first and uses the labels of the repo. It sets Priority and Size only when it is sure. Otherwise the board workflow sets the defaults. |
| `refine-issue` | Any time | Rewrites a rough issue into a summary, to-do list and definition of done. On a refined issue, it applies the changes that you ask for in new comments, and ticks off its checkboxes as work lands. A hidden marker in the body shows which comments are new. It updates the issue directly and reports what it changed. |

**Install** (in Claude Code):

```text
/plugin marketplace add SNprime24/SN-Github-Automation
/plugin install issue-workflow@sn-github-automation
```

**Update** after a new version is pushed here:

```text
/plugin marketplace update sn-github-automation
```

**Which board?** The skills don't name one. They use the board your own setup names. For example, add a line like this to your `~/.claude/CLAUDE.md`, which stays on your machine:

```markdown
My project board: user <login>, project <number>. Use the issue-workflow skills when you create, start and finish work on an issue.
```

Without that line, they use the board the issue's card is already on, and ask if there's more than one or none. Columns are matched by name: **In Progress**, and any column containing "Review" (such as `In Review / Testing`).

The skills use the GitHub and GitHub Projects MCP servers, and fall back to the `gh` CLI only when those aren't available. Either way, the board moves need access with the `project` scope (for `gh`: `gh auth refresh -s project`).

## Versioning

Callers pin to a major version, such as `@v1`, rather than `@main`.

- **Fixes and new options that don't change behaviour** go out as `v1.x.y`. The `v1` tag moves forward to the latest `v1.x.y`, so callers on `@v1` get them automatically.
- **Breaking changes** (renamed or removed inputs, different defaults, different behaviour) go out as `v2`. Callers on `@v1` keep working until they choose to move.

Pinning to `@main` isn't recommended, because a broken commit there would break every caller at once.

The Claude Code plugin is versioned separately, by the `version` in [`plugin.json`](plugins/issue-workflow/.claude-plugin/plugin.json). Bump it with every change to the plugin, or `/plugin marketplace update` won't pick the change up.

## Layout

```text
.claude-plugin/      The Claude Code marketplace manifest (marketplace.json)
.github/workflows/   Reusable workflows (on: workflow_call) and this repo's own workflows
actions/<name>/      One composite action per folder: action.yml, its scripts and a short README
plugins/<name>/      One Claude Code plugin per folder: .claude-plugin/plugin.json and its skills
lib/                 Shell helpers shared by the actions' scripts
tests/<name>/        Tests for the action of the same name
tests/lib/           The fake gh and the test helpers the tests share
```

New additions go where they fit:

- **A step other workflows can use** → a new folder under `actions/`, named after what it does (for example `actions/add-to-board/`).
- **A whole job other repos call** → a reusable workflow in `.github/workflows/`.

Each new action or workflow also gets a row in [What's here](#whats-here), and its tests a job in `lint.yml`.

## Development

Every pull request runs [`lint.yml`](.github/workflows/lint.yml):

- **actionlint** on the workflows, which also runs shellcheck on their `run:` blocks
- **shellcheck** on the scripts in `lib/`, `actions/` and `tests/`
- **The script tests**, which run each action's scripts against a fake `gh` and check exactly which changes they make
- **The no-token checks:** add-to-board must skip without a token, and board-sweep and sprint-rollover must fail
- **The plugin manifests** must be valid JSON. For a fuller check, run `claude plugin validate .` and `claude plugin validate plugins/issue-workflow` locally

The script tests can also be run locally with bash and jq:

```bash
bash tests/add-to-board/test-set-fields.sh
bash tests/board-sweep/test-board-sweep.sh
bash tests/sprint-rollover/test-sprint-rollover.sh
```

## Requirements

- The repo must be **public** before public repositories can use its actions. Actions in a private repo can only be used by other private repos of the same owner, and only when **Settings → Actions → General → Access** allows it.
- Every repo that uses the board automation needs its own `BOARD_TOKEN` secret. Personal accounts have no shared Actions secrets.

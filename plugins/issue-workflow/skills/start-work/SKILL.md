---
name: start-work
description: Start work on a GitHub issue before writing any code. Reads the issue, creates a branch named <type>/<repo-initials>-<issue-number>-<short-slug>, and moves the issue's card to In Progress on its project board. Use whenever you are about to work on an issue, or when asked to start, pick up, begin or "do" one (e.g. "start issue 12", "pick up #7", "let's do issue 24").
argument-hint: "[repo] <issue-number>"
---

# Start work on an issue

Run this **before** changing any code for an issue. When the work is done, use the `finish-work` skill.

## 1. Find the issue

Arguments: `$ARGUMENTS`

- **Issue number:** a bare number or `#12`.
- **Repo:** `owner/name`, or a bare name meaning the current repo's owner. Default: the repo of the current directory (from `git remote get-url origin`).
- **Issue URL:** gives both.

If nothing is given, use the issue named in the request. If there is still none, ask.

## 2. Read it

Read the title, body, labels, state and comments (GitHub MCP `issue_read`, or `gh issue view <n> --repo <owner/name> --comments`).

- If it is **closed**, ask before going on.
- If it has a **To-do** or **Done when** list, that is the plan for the work.
- If it is too vague to start, say what's missing. Offer the `refine-issue` skill.

## 3. Name the branch

Format: **`<type>/<repo-initials>-<issue-number>-<short-slug>`**, all lowercase.

| Part | Rule |
|---|---|
| `type` | From the labels first, then the issue text: bug → `fix`; feature or enhancement → `feat`; documentation → `docs`; refactor → `refactor`; tests → `test`; anything else → `chore`. |
| `repo-initials` | The first letter of each word in the repo name, splitting on `-`, `_`, `.` and camelCase: `my-sample-repo` → `msr`, `SN-Github-Automation` → `sga`. A one-word name uses its first three letters: `website` → `web`. |
| `issue-number` | The issue's number, no `#`. |
| `short-slug` | 2–5 words from the title, lowercase and joined by hyphens, with filler words (a, the, for, to) dropped. ASCII letters, digits and hyphens only. |

Examples: `feat/sga-24-claude-plugin`, `fix/msr-7-login-timeout`, `docs/web-3-readme-setup`.

If the user's own instructions give a different format, theirs wins.

## 4. Create the branch

1. **Working tree must be clean.** If `git status` shows uncommitted changes, stop and ask what to do with them. Don't stash or discard them yourself.
2. **Branch already exists?** Check local and remote (`git branch -a --list '*<repo-initials>-<issue-number>-*'`). If a branch for this issue exists, switch to it and pull instead of creating a second one, and say so.
3. **Otherwise** branch from the up-to-date default branch:

   ```bash
   git switch <default-branch>
   git pull --ff-only
   git switch -c <branch-name>
   ```

   If `pull --ff-only` fails, stop and tell the user; don't merge or rebase on your own.

Don't push yet. `finish-work` pushes.

## 5. Move it to In Progress in Board

Follow [board-moves.md](../../references/board-moves.md): find the board, pick the **In Progress** column, set it and read it back. If the card is already In Progress, leave it.

## 6. Report

In two or three lines: the branch name, the board move (or why it was skipped), and the plan you'll follow from the issue. Then start the work.

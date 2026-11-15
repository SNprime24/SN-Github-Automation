---
name: finish-work
description: Finish work on a GitHub issue. Commits what's left, pushes the branch, opens a pull request that closes the issue, then moves the issue's card to Review on its project board. Never merges. Use when the work for an issue is done, or when asked to finish, wrap up, ship, "open the PR" or "send it for review" (e.g. "finish issue 12", "open a PR for this", "move it to review").
argument-hint: "[repo] [issue-number]"
---

# Finish work on an issue

**Tools:** use the GitHub MCP tools for issues and pull requests, and the GitHub Projects MCP tools for the board. Use the `gh` CLI only as a fallback, when those tools aren't available or keep failing.

Run this when the code for an issue is done. It pairs with `start-work`.

## 1. Work out the issue and branch

- **Branch:** the current one. If it is the default branch (`main`, `master`), stop: the work belongs on a feature branch. Offer to create one with `start-work`.
- **Issue:** from the arguments, the request, or the branch name (`<type>/<repo-initials>-<issue-number>-<slug>` → the number after the initials). If none can be found, ask.

## 2. Check the work

- Read the issue's **To-do** and **Done when** lists, if it has them, and compare them with the changes (`git diff <default-branch>...HEAD` plus anything uncommitted). If something is clearly missing, say so and ask whether to finish it first or open the PR anyway.
- If the repo has a quick, documented check (a test or lint command in its README, `CONTRIBUTING.md` or CI config), run it. If it fails, show the output and stop. Don't open a PR on a failing check without the user's OK.

## 3. Commit and push

- If there are uncommitted changes that belong to this work, commit them with a short message in the style of the repo's recent commits (`git log --format=%s -10`). Leave out files that don't belong to the issue (local settings, scratch files) and mention them.
- Follow the user's own instructions about commit and PR attribution lines. They override any default.
- Push: `git push -u origin <branch>`. Never force-push unless the user asks.

## 4. Open the pull request

- **Base:** the repo's default branch.
- **Template:** if the repo has `.github/pull_request_template.md` or `.github/PULL_REQUEST_TEMPLATE/`, fill it in.
- **Title:** a short summary of the change, in the style of earlier PR titles.
- **Body:** what changed and why, how it was tested, and a closing line that links the issue: `Closes #<n>` for the same repo, `Closes <owner>/<repo>#<n>` for another one.
- If a PR for this branch already exists, update it instead of opening a second one.

Use GitHub MCP `create_pull_request` (fallback `gh pr create`). **Never merge the PR and never turn on auto-merge.** The user reviews and merges.

## 5. Move it to Review in Board

Only **after** the PR call has returned. Linking a PR can set off a board automation, and moving the card at the same time can be overwritten.

Follow [board-moves.md](../../references/board-moves.md): find the board, pick the **Review** column, set it, then read the card back and set it once more if an automation moved it.

## 6. Report

In two or three lines: the PR link, the board move (or why it was skipped), and anything left undone or unchecked. If the issue has To-do / Done when checkboxes, offer to tick them off with the `refine-issue` skill (update mode).

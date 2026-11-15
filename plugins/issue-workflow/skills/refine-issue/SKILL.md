---
name: refine-issue
description: Turn a GitHub issue that was written quickly (a rough title, an empty or half-filled body) into a clear task with a clean title, a summary, a to-do checklist, a definition of done, notes, and the right labels. Also updates an issue that's already refined, ticking off its To-do and Done when checkboxes as work gets done. Asks the owner questions when something can't be inferred, shows the draft or the changes, and updates the issue only after they approve. Use when asked to refine, clean up, polish, rewrite, expand or "fix up" an issue (e.g. "refine issue 14", "clean up my rough issues"), or to update its progress, tick or check off its boxes, or mark steps done (e.g. "update issue 15", "tick off what's done on 17").
argument-hint: "[update] [repo] [issue-no]"
---

# Refine an issue

Issues written in a hurry often have a long, typo-filled title and a body that is just an empty form (`_No response_`). This skill rewrites such an issue into a proper task **without losing anything that was written**, asking the owner questions where needed. Later, as work gets done, it also ticks off that task's checkboxes (*update mode*, step 7).

## 1. Pick the issue(s)

Arguments: `$ARGUMENTS`

Read the arguments in any order:

- **Issue number(s):** any bare number, `#14`, or a list such as `14 15`.
- **Repo:** a word that isn't a number. A bare name means `<current repo's owner>/<name>`; `owner/name` is used as given. **Default: the repo of the current directory.**
- **Issue URL:** gives both repo and number.
- **`update`** (also `tick`, `check`): update mode. This word is never a repo name.

Examples: `/refine-issue 14`, `/refine-issue my-app 3`, `/refine-issue https://github.com/<owner>/<repo>/issues/2`, `/refine-issue update 15`.

If the arguments are empty, the request in chat may still name the issue ("refine issue 14", "tick off what's done on 15"); use that.

**Pick the mode for each issue:**

- **Update mode** (step 7) when the arguments say `update`, the request is about progress ("mark it done", "tick off", "update the checkboxes"), or the issue is already refined: its body has `## To-do` or `## Done when` checkboxes. For an already-refined issue that nobody asked to update, confirm first: *Update its checkboxes* / *Refine it again*.
- **Refine mode** (steps 2–6) otherwise.

- If no issue number was given at all, list open issues in the chosen repo and pick those that look rough: a body with only `_No response_` fields, no labels, a title longer than ~10 words or full of typos. Show the list and ask which ones to refine. In update mode, list open issues that have unchecked boxes instead.
- Handle **one issue at a time**, finishing each (approved or skipped) before the next.

## 2. Gather context

Read before you write:

- The issue itself: title, body, labels, state, comments (GitHub MCP `issue_read`, or `gh issue view <n> --repo <owner/name> --comments`).
- Its family: parent issue and sub-issues. A sub-issue's scope comes from its parent, and a parent's to-do list should mention its sub-issues.
- Anything the issue names: a file, workflow or doc in the repo (read it), or a linked issue or PR.
- The repo's **label conventions**: its labels (`gh label list`), plus any rules in its README or `CONTRIBUTING.md`.
- Its **board card**, if it has one: find the board as in [board-moves.md](../../references/board-moves.md), and read the card's fields (for example Priority, Size, Sprint, Due date) so the suggestion builds on what's already set.

## 3. Ask the owner what you can't infer

Use `AskUserQuestion`: at most 4 questions per round, and usually no more than 2 rounds. Ask only questions whose answers change the draft, for example:

- **Goal / done:** what does finished look like? (offer your best guess as the first option)
- **Scope:** which of two readings is meant, or what is explicitly out of scope
- **Missing facts:** which tool, which repo, which account, which deadline
- **Due date**, if the work sounds time-bound and the board has a date field
- **Split:** if it looks bigger than 2–3 days, whether to split it into sub-issues

Don't ask about things the issue, its parent, the repo or its docs already answer. Don't ask about wording; just write it well. If the issue is already clear, skip this step.

## 4. Draft the refined issue

**Title:** a short action in sentence case, ideally under 10 words, typos fixed, e.g. *Add README table of workflow runs and costs*. Keep the owner's meaning, not their exact words.

**Body:** use this structure. Leave out a section only if it would be empty, but always keep *Done when*, *Notes* and the original text.

If the issue form put values that have a proper home elsewhere into the body (a due date that belongs on the board card, a category that is a label), move them there instead of keeping a copy in the body, which goes stale.

```markdown
## Summary
One or two sentences: what this is and why it matters.

## Context
Background, the parent issue (#N), related files, issues or links. Leave this out if there's none.

## To-do
- [ ] Concrete step, starting with a verb
- [ ] …
- [ ] Sub-issue #N (for a parent issue)

## Done when
- [ ] Checkable outcome (e.g. "README has a table with workflow, runs/month and monthly cost")

## Notes
Open questions, assumptions you made, anything the owner said in answers that doesn't fit above.

<details><summary>Original issue text</summary>

The original title and body, exactly as written.

</details>
```

Rules:

- **Keep the original.** Put the original title and body in the `<details>` block, unchanged, every time.
- **Don't make things up.** If something wasn't stated or answered, put it under *Notes* as an assumption or open question rather than presenting it as fact.
- **To-do items** should take a few hours at most each. If there are more than ~8, suggest splitting.
- **Keep it short.** A small task needs a short issue.
- **Public repos:** don't add private details (private repo names, internal links, tokens) that the original didn't already contain.

**Labels:** only labels the repo already has, following its documented conventions. Typically one type label (bug, feature/enhancement, docs, …) plus any category or area label the repo uses. Keep labels the owner already added unless they contradict the new ones; if they do, ask. Don't create new labels without asking.

**Board suggestion** (don't apply yet), only for fields the board actually has: for example Priority and Size from their existing options, with a one-line reason each, and a Due date (YYYY-MM-DD) if there is one. If the card already has a different value, show both and ask which to keep. No deadline means leave the date empty.

## 5. Show the draft and get approval

Show the owner, in chat:

1. Old title → new title
2. The new body, rendered as markdown
3. Labels to add or remove
4. The board suggestion, if any

Then ask with `AskUserQuestion`: **Update the issue** / **Change something** / **Skip it**. On *Change something*, revise and show it again. Never write to GitHub before a clear yes for that specific issue.

## 6. Apply

Once approved:

- Update title, body and labels (GitHub MCP `issue_write` with method `update`, or `gh issue edit`). Don't change state, assignees, milestone or issue type.
- If the owner agreed to a split, create each sub-issue with the same structure and link it to the parent.
- If the owner accepted the board suggestion, set those fields on the card. Otherwise leave the board alone.
- Report the issue link and what changed in one or two lines, then go on to the next issue if there is one.

## 7. Update mode: tick off checkboxes

For an issue that's already refined. The job is to bring its checkboxes up to date, not to rewrite it.

1. **Read** the issue body, comments and sub-issues, and look for evidence of progress: PRs that reference or close the issue, recent commits, and the files the To-do names (check whether the change is actually there, on the default branch or on the PR's branch).
2. **Work out each box.** Mark a box done only when there is evidence or the owner says so. When evidence is missing or only partial, ask: one `AskUserQuestion` with `multiSelect` per section (To-do, Done when), listing the unchecked items, with your evidence in each description. At most 4 items per question, so split long lists. Also ask whether any ticked box should be unticked if the evidence says the work was undone.
3. **Show the changes** in chat: each box that changes (`[ ]` → `[x]` or back), with its reason, and how many boxes are done out of how many in each section. If the owner mentioned new steps or facts, show them as added To-do items or *Notes* lines. Ask **Update the issue** / **Change something** / **Skip it**.
4. **Apply** by updating the `body` only. Start from the body you just read and change only the checkbox characters and any agreed additions. Every other character stays the same, including the original text in `<details>`. Re-read the issue just before writing; if it changed since step 1, start again from the new body.
5. **Don't** change the title, labels, state or the board card. If every Done when box is now ticked, say so: the issue closes when its PR merges, or the owner can close it.

# Issue format

The `create-issue` and `refine-issue` skills use this format. Change the format here, not in a skill.

## Title

- Write a short action in sentence case. Example: *Add README table of workflow runs and costs*.
- Use a maximum of 10 words.
- Correct the typos. Keep the meaning of the owner, not the exact words.

## Body

Use this structure. If a section has no content, remove it. Always keep *Done when* and *Notes*.

```markdown
## Summary
One or two sentences: what the task is and why it is necessary.

## Context
Background, the parent issue (#N), related files, issues or links.

## To-do
- [ ] One concrete step. Start with a verb.
- [ ] …
- [ ] Sub-issue #N (for a parent issue)

## Done when
- [ ] One result that you can check. Example: "The README has a table with workflow, runs each month and monthly cost."

## Notes
Open questions, assumptions, and facts from the owner that do not go in a different section.

<!-- issue-workflow: refined 2026-11-15T08:30:00Z -->
```

`refine-issue` also adds the original text before the marker. See that skill.

## Marker

The last line of the body is a hidden marker. GitHub does not show it.

```markdown
<!-- issue-workflow: refined <UTC time> -->
```

- Write the time in the format `YYYY-MM-DDTHH:MM:SSZ`, in UTC.
- `create-issue` adds the marker. `refine-issue` adds it or changes its time after each change.
- Use the time when you read the comments of the issue, not the time when you write. Then a comment that arrives while you work is not lost.
- A comment from the owner after this time is a **new comment**. `refine-issue` applies new comments. See that skill.
- Keep only one marker. If you find more than one, keep the last one and remove the others.

## Rules

- **Do not invent facts.** If the owner did not give a fact, write it under *Notes* as an assumption or an open question.
- **Keep To-do items small.** Each item must take a maximum of a few hours. If there are more than approximately 8 items, recommend a split.
- **Keep it short.** A small task needs a short issue.
- **Public repos:** do not write private details, for example private repo names, internal links or tokens.
- **Values with a different location:** a due date goes on the board card. A category goes in a label. Do not copy them into the body, because a copy becomes old.
- **Writing style:** write all text as [writing-style.md](writing-style.md) tells you. If the user's own `CLAUDE.md` has writing rules, they have priority.

## Labels

- Use only labels that the repo has. Get them with the GitHub MCP label tools (fallback: `gh label list`).
- Follow the label rules in the README or `CONTRIBUTING.md` of the repo, if they exist.
- Usually use one type label (bug, feature or enhancement, docs, …). Add a category or area label if the repo uses them.
- Do not make new labels.

## Board fields

Set only the fields that the board has, with their existing options. Examples: Priority, Size, Due date (YYYY-MM-DD). If there is no deadline, leave the date empty.

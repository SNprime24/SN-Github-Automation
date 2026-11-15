---
name: create-issue
description: Create a clear GitHub issue from a short request. Writes the title, summary, to-do list, definition of done and notes in the shared issue format, adds labels from the repo, and sets Priority and Size on the board only when sure. Creates the issue without waiting for approval and gives the link. Use when asked to create, open, make, file, log or write an issue or task (e.g. "create an issue for the login bug", "open an issue to add dark mode", "/create-issue add a README").
argument-hint: "[repo] <short request>"
---

# Create an issue

**Tools:** use the GitHub MCP tools for issues, and the GitHub Projects MCP tools for the board. Use the `gh` CLI only as a fallback, when those tools are not available or fail again and again.

This skill makes a clear issue from a short request. It uses the same format as `refine-issue`: [issue-format.md](../../references/issue-format.md).

## 1. Find the repo and the request

Arguments: `$ARGUMENTS`

- **Repo:** `owner/name`, or a bare name for a repo of the current owner. The default is the repo of the current directory (`git remote get-url origin`).
- **Request:** the remaining text. If there is no text, use the request in chat.

If you cannot find the repo or the request, ask.

## 2. Look for a duplicate

Search the open issues of the repo for the same task (GitHub MCP `search_issues` or `list_issues`). If an open issue has the same task, give its link and stop. If an issue is only related, continue and put its link in *Context*.

## 3. Read the context

- Read the files, workflows, docs, issues and PRs that the request names.
- Read the labels of the repo and its label rules.
- If the request names a parent issue, read it. Its scope controls the scope of the new issue.

## 4. Ask only if the goal is not clear

If you cannot write a correct *Done when*, ask the owner with `AskUserQuestion`. Ask a maximum of 4 questions, in one round. Put your best guess as the first option.

Do not ask about the wording. Do not ask about Priority or Size.

## 5. Write the issue

Write the title, body and labels as [issue-format.md](../../references/issue-format.md) tells you.

- Keep it short. A small request needs a short issue.
- Do not add the original request to the body. In a public repo it can contain private details.
- If the request is larger than 2–3 days of work, write one parent issue. Recommend sub-issues in *Notes*. Do not make the sub-issues without the answer of the owner.

## 6. Create it

Create the issue (GitHub MCP `issue_write` with method `create`; fallback `gh issue create`). Do not wait for approval. If a parent issue was named, attach the new issue to it as a sub-issue.

## 7. Set Priority and Size only if you are sure

Many repos have a workflow that puts each new issue on the board and sets default values in empty fields. Because of this, an empty field is correct when you are not sure.

| Field | Set it only when | Example |
|---|---|---|
| **Priority** | The request or the owner gives the urgency clearly. | "urgent", "it blocks the release" → High or Critical. "some day", "no rush" → Low. |
| **Size** | The To-do list makes the effort clear. | 1–2 small items → S. A large or unclear task → leave it empty. |

Use only the options that the board has. Do not set Sprint, Status or Due date, unless the owner gave them.

To set a field, find the card as [board-moves.md](../../references/board-moves.md) tells you:

- If the instructions of the user name a board, add the issue to that board (`add_project_item`). This is safe if the workflow added it already.
- If not, look for the card on the boards of the owner. If there is no card, do not add one. Report that you did not set the fields.

## 8. Report

Give, in a few lines:

- The issue link and title
- The labels
- The board fields that you set, or "Priority and Size empty: the workflow sets the defaults"
- A related issue, if you found one in step 2

Do not start work on the issue. To start, use `start-work`.

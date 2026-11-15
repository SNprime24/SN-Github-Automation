# Moving an issue's card on its board

Shared steps for the skills in this plugin. "The board" is the GitHub Projects board the issue's card is on. Nothing here names a specific board: each user's own setup decides which one.

## 1. Find the board

Use the first of these that gives an answer:

1. **The user's own instructions.** Their `CLAUDE.md` files or memory may name a board, for example "My board: user `<login>`, project `<number>`". Use it.
2. **The boards the issue is already on.** Look them up (query below). If it is on exactly one, use that one. If it is on several, ask which one.
3. **Nothing found.** Tell the user the issue isn't on any board, and ask whether to add it (and to which board) or skip the board step. Don't add it on your own.

Query with the `gh` CLI (replace `OWNER`, `REPO`, `NUMBER`):

```bash
gh api graphql -f owner=OWNER -f repo=REPO -F number=NUMBER -f query='
query($owner: String!, $repo: String!, $number: Int!) {
  repository(owner: $owner, name: $repo) {
    issue(number: $number) {
      projectItems(first: 20) {
        nodes {
          id
          project { id number title owner { ... on User { login } ... on Organization { login } } }
          status: fieldValueByName(name: "Status") {
            ... on ProjectV2ItemFieldSingleSelectValue { name }
          }
        }
      }
    }
  }
}'
```

## 2. Pick the column

Columns are the options of the board's single-select **Status** field. List them (GitHub Projects MCP `list_project_fields`, or `gh project field-list <number> --owner <login> --format json`) and match by meaning, case-insensitively:

| Move it to… | Use the first option that matches |
|---|---|
| **In Progress** | `In Progress` exactly, then any option containing "progress" or "doing" |
| **Review** | any option containing "review" (e.g. `Review`, `In Review`, `In Review / Testing`), then one containing "testing" or "QA" |

If nothing matches, or two options match equally well, ask which one to use. Never create or rename columns.

## 3. Set it and check it

- **With the GitHub Projects MCP tools:** `update_project_item` with `item_owner`, `item_repo` and `issue_number`, and `updated_field` `{"name": "Status", "value": "<option name>"}`.
- **With `gh`:** `gh project item-edit --project-id <project id> --id <item id> --field-id <Status field id> --single-select-option-id <option id>`. The `gh project` commands need a token with the `project` scope (`gh auth refresh -s project`).

Then **read the card back** and confirm the Status is the one you set. Some boards have automations that move a card when a pull request links to it. If the card has moved back, set it again once and say so in your report.

If the move fails (missing scope, no access), carry on with the rest of the task and tell the user exactly what failed and how to fix it. Don't block the code work on the board.

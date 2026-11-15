# Moving an issue's card on its board

Shared steps for the skills in this plugin. "The board" is the GitHub Projects board the issue's card is on. Nothing here names a specific board: each user's own setup decides which one.

**Tools:** use the **GitHub Projects MCP tools** (`projects_list`, `projects_get`, `projects_write`). Use the `gh` CLI only as a fallback, when those tools aren't available or keep failing. The fallback commands are at the end.

## 1. Find the board

Use the first of these that gives an answer:

1. **The user's own instructions.** Their `CLAUDE.md` files or memory may name a board, for example "My board: user `<login>`, project `<number>`". Use it.
2. **The boards the issue is already on.** `list_projects` for the issue's repo owner, and for the user if that's someone else. For each open board, `list_project_items` with the query `repo:<owner>/<repo> is:issue` and the field name `Status`, and look for the issue's number. If it is on exactly one board, use that one. If it is on several, ask which one.
3. **Nothing found.** Tell the user the issue isn't on any board, and ask whether to add it (and to which board) or skip the board step. Don't add it on your own.

## 2. Pick the column

Columns are the options of the board's single-select **Status** field. List them with `list_project_fields` and match by meaning, case-insensitively:

| Move it to… | Use the first option that matches |
|---|---|
| **In Progress** | `In Progress` exactly, then any option containing "progress" or "doing" |
| **Review** | any option containing "review" (e.g. `Review`, `In Review`, `In Review / Testing`), then one containing "testing" or "QA" |

If nothing matches, or two options match equally well, ask which one to use. Never create or rename columns.

## 3. Set it and check it

`update_project_item` with `item_owner`, `item_repo` and `issue_number`, and `updated_field` `{"name": "Status", "value": "<option name>"}`.

Then **read the card back** (`get_project_item` with the item's ID and the field name `Status`) and confirm the Status is the one you set. Some boards have automations that move a card when a pull request links to it. If the card has moved back, set it again once and say so in your report.

If the move fails (missing scope, no access), carry on with the rest of the task and tell the user exactly what failed and how to fix it. Don't block the code work on the board.

## Fallback: the `gh` CLI

Only when the MCP tools aren't available. The `gh project` commands need a token with the `project` scope (`gh auth refresh -s project`).

- **Find the boards an issue is on** (replace `OWNER`, `REPO`, `NUMBER`):

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

- **List the columns:** `gh project field-list <number> --owner <login> --format json`
- **Set the Status:** `gh project item-edit --project-id <project id> --id <item id> --field-id <Status field id> --single-select-option-id <option id>`
- **Read it back:** run the "find the boards" query again and check `status`.

# Releasing

This repo has two kinds of release. Each kind has its own tags, its own steps and its own notes.

| Kind | Tag | Release title | Latest release |
|---|---|---|---|
| The GitHub Actions in `actions/` | `v<major>.<minor>.<patch>`, plus the major tag `v<major>` | `Actions v2.0.2` | Yes |
| The `issue-workflow` Claude Code plugin | `issue-workflow-v<version>`, plus the major tag `issue-workflow-v<major>` | `issue-workflow plugin 1.2.0` | No |

The examples below use `v2.0.2` for the Actions and `1.2.0` for the plugin. Change them to the version that you release.

## Rules for all releases

- Release only from `main`, after the pull request is merged.
- Make an **annotated** tag (`git tag -a`) and push it before you make the release.
- Use `--verify-tag` with `gh release create`. Without it, `gh` makes a lightweight tag when the tag is missing.
- If you must give a commit with `--target`, use the full commit SHA. A short SHA fails.
- Write the notes in a file, for example `notes.md`, and give it with `--notes-file`. Do not commit that file.
- Keep the notes generic. This repo is public, so do not name private repos, boards or people.

## Actions release

### Pick the version

- **Patch** (`v2.0.1` → `v2.0.2`): a fix. Inputs, outputs and behaviour do not change.
- **Minor** (`v2.0.2` → `v2.1.0`): a new optional input or a new feature. Callers do not have to change.
- **Major** (`v2.1.0` → `v3.0.0`): a breaking change. For example, a renamed or removed input, a different default, or different behaviour.

### Steps

1. Merge the changes to `actions/` or `lib/` into `main`.
2. Make and push an annotated tag:

   ```bash
   git switch main
   git pull --ff-only
   git tag -a v2.0.2 -m "Actions v2.0.2"
   git push origin v2.0.2
   ```

3. Move the major tag to the new release. Callers on `@v2` then get it:

   ```bash
   git tag -fa v2 -m "Point v2 to v2.0.2" v2.0.2^{}
   git push origin v2 --force
   ```

   The `^{}` makes `v2` point to the commit, not to the `v2.0.2` tag object. For a **major** release, do not move the old major tag. Make a new one instead, and push it without `--force`:

   ```bash
   git tag -a v3 -m "Point v3 to v3.0.0" v3.0.0^{}
   git push origin v3
   ```

4. Make the release. It is the **Latest** release:

   ```bash
   gh release create v2.0.2 --verify-tag --title "Actions v2.0.2" --notes-file notes.md --latest
   ```

5. Make sure that both tags point to the same commit:

   ```bash
   git rev-parse v2.0.2^{} v2^{}
   ```

6. For a major release, update the **Versioning** section and the `@v<major>` examples in `README.md` and in each action README.

### Notes template for the Actions

````markdown
<One line: what changed in this release.> Use the actions with `@v2`. The `v2` tag points to this release.

## <Fix | New | Breaking change>

- **<action name>:** <What changed and why. Give the PR and the issue.> (PR #<n>, issue #<n>)

## Actions

| Action | What it does |
|---|---|
| `actions/add-to-board` | <Copy from the last release. Change only what is new.> |
| `actions/board-sweep` | <…> |
| `actions/sprint-rollover` | <…> |

## Usage

<Copy the caller examples from the last release. Change only what is new.>

## History of v2

- v2.0.2: <what changed> (PR #<n>)
- v2.0.1: <copy from the last release>
- v2.0.0: <copy from the last release>

## Versioning

- Fixes and new options that do not change behaviour come as `v2.x.y`. The `v2` tag moves to the newest one.
- Breaking changes come as `v3`.
````

For a **major** release, also add these sections after the first line:

- **Breaking change:** what changed, and why.
- **Move a caller from v2 to v3:** the steps, and a caller example for each action that changed.
- **Tested on a real board:** the cases that you tested, and what you did not test.

## Plugin release

### How users get the plugin

Users get the plugin from the moving major tag `issue-workflow-v1`, not from `main`. This is the gate:

- You can merge plugin changes to `main` at any time. Users do not get them.
- Users get a new release only when you move `issue-workflow-v1`.
- If a release is bad, you can move `issue-workflow-v1` back to the last good release.

> **The gate is not active yet.** At this time, `.claude-plugin/marketplace.json` uses the relative source `./plugins/issue-workflow`, so new installs get `main`. Issue #47 changes the source to the tag `issue-workflow-v1`. Until then, keep `main` in a state that works.

### When to change the version

Change `version` in [`plugins/issue-workflow/.claude-plugin/plugin.json`](plugins/issue-workflow/.claude-plugin/plugin.json) **only in the release commit**. Do not change it in the pull requests that change the plugin.

Claude Code compares this version with the version in its cache. If you move the tag but do not change the version, users keep their cached copy.

- **Patch** (`1.1.0` → `1.1.1`): a fix.
- **Minor** (`1.1.1` → `1.2.0`): a new skill, or a change that users see and that is compatible.
- **Major** (`1.2.0` → `2.0.0`): a renamed or removed skill, or a change that users must adapt to.

### Steps

1. Merge the plugin changes to `main`. Do not change `version`.
2. Change `version` in `plugin.json` in a release pull request, and merge it.
3. Make and push an annotated tag on that commit:

   ```bash
   git switch main
   git pull --ff-only
   git tag -a issue-workflow-v1.2.0 -m "issue-workflow plugin 1.2.0"
   git push origin issue-workflow-v1.2.0
   ```

4. Make the release. It is **not** the Latest release, so the Actions release stays Latest:

   ```bash
   gh release create issue-workflow-v1.2.0 --verify-tag --title "issue-workflow plugin 1.2.0" --notes-file notes.md --latest=false
   ```

5. Move the major tag to the new release. Users get the release at this step:

   ```bash
   git tag -fa issue-workflow-v1 -m "Point issue-workflow-v1 to 1.2.0" issue-workflow-v1.2.0^{}
   git push origin issue-workflow-v1 --force
   ```

   For a **major** release, make a new tag `issue-workflow-v2`, and change `ref` in `marketplace.json` to it. All users then move to the new major version.

6. Update your own install:

   ```bash
   claude plugin marketplace update sn-github-automation
   claude plugin update issue-workflow@sn-github-automation
   ```

7. Make sure that the update reports the new version. Then start a new session, or run `/reload-plugins`.

### Roll back a bad release

Use one of these methods:

- **Fix forward (recommended):** revert the bad change on `main`, and release a new patch version, for example `1.2.1`.
- **Move the tag back:** point `issue-workflow-v1` to the last good release:

  ```bash
  git tag -fa issue-workflow-v1 -m "Point issue-workflow-v1 back to 1.1.0" issue-workflow-v1.1.0^{}
  git push origin issue-workflow-v1 --force
  ```

  Claude Code updates when the version is different. An update to a lower version is not tested yet. Issue #47 tests it.

- **For one user only:** add the marketplace with an exact tag, for example `claude plugin marketplace add SNprime24/SN-Github-Automation#issue-workflow-v1.1.0`.

### Notes template for the plugin

````markdown
<One line: the main change in this release.>

## What is new

- **<Short name>.** <One bullet for each change that users see.>

## Install

```text
/plugin marketplace add SNprime24/SN-Github-Automation
/plugin install issue-workflow@sn-github-automation
```

## Update from <last version>

```text
/plugin marketplace update sn-github-automation
/plugin update issue-workflow@sn-github-automation
```

Then start a new session, or run `/reload-plugins`. The update must report version <new version>.

## Changes in this release

- #<issue>: <what changed> (PR #<n>)
- Plugin version <new version> (PR #<n>)

## Known limits

- <What does not work yet.>
- This release is for the plugin only. The GitHub Actions use the `v<major>` tags.
````

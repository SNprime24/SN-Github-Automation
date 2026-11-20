# Releasing

This repo has two kinds of release. Each kind has its own tags, its own steps and its own notes.

| Kind | Tag | Release title | Latest release |
|---|---|---|---|
| The GitHub Actions in `actions/` | `v<major>.<minor>.<patch>`, plus the major tag `v<major>` | `Actions v2.0.2` | Yes |
| The `issue-workflow` Claude Code plugin | `issue-workflow-v<version>` | `issue-workflow plugin 1.2.0` | No |

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

- Claude Code reads the plugin from `main`. The source in `.claude-plugin/marketplace.json` is the relative path `./plugins/issue-workflow`.
- Users who have the plugin get a new copy only when `version` in `plugin.json` changes.
- A new install gets `main` as it is, so keep `main` in a state that works.
- Each release tag `issue-workflow-v<version>` is a checkpoint. If a release fails, users can install an earlier release tag. See [Roll back a bad release](#roll-back-a-bad-release).

### When to change the version

Change `version` in [`plugins/issue-workflow/.claude-plugin/plugin.json`](plugins/issue-workflow/.claude-plugin/plugin.json) **only in the release commit**. Do not change it in the pull requests that change the plugin.

Claude Code compares this version with the version in its cache. Users who have the plugin get the changes on `main` only when this version changes.

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

5. Update your own install:

   ```bash
   claude plugin marketplace update sn-github-automation
   claude plugin update issue-workflow@sn-github-automation
   ```

6. Make sure that the update reports the new version. Then start a new session, or run `/reload-plugins`.

### Roll back a bad release

1. Find the last good release tag, for example `issue-workflow-v1.1.0`.
2. Tell users which release tag to install. Write it in two places:
   - At the top of the notes of the bad release (`gh release edit issue-workflow-v1.2.0 --notes-file notes.md`).
   - In the plugin section of `README.md`, as a short **Known problem** note.
3. Users install that release tag with these commands:

   ```bash
   claude plugin marketplace remove sn-github-automation
   claude plugin marketplace add SNprime24/SN-Github-Automation#issue-workflow-v1.1.0
   claude plugin install issue-workflow@sn-github-automation
   ```

4. Revert the bad change on `main`, and release a new patch version, for example `1.2.1`.
5. Remove the **Known problem** note from `README.md`. Tell users to go back to `main`:

   ```bash
   claude plugin marketplace remove sn-github-automation
   claude plugin marketplace add SNprime24/SN-Github-Automation
   claude plugin install issue-workflow@sn-github-automation
   ```

A marketplace that is added with a release tag stays on that tag. It does not get new releases until the user adds it again without the tag.

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

## Go back to this version

If a later release fails, install this release tag:

```bash
claude plugin marketplace remove sn-github-automation
claude plugin marketplace add SNprime24/SN-Github-Automation#issue-workflow-v<new version>
claude plugin install issue-workflow@sn-github-automation
```

## Changes in this release

- #<issue>: <what changed> (PR #<n>)
- Plugin version <new version> (PR #<n>)

## Known limits

- <What does not work yet.>
- This release is for the plugin only. The GitHub Actions use the `v<major>` tags.
````
